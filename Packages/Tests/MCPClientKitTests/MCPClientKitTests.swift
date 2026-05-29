import Foundation
import MCPClientAPI
@testable import MCPClientKit
import Testing
import TransportAPI

@Suite("MCPClient")
struct MCPClientKitTests {
    /// Concurrent requests must each get their own response (regression for the
    /// reentrancy bug where a second in-flight request overwrote the first's
    /// continuation, hanging it and cross-delivering responses). The fake replies
    /// per request id with a tool-specific payload; both calls must resolve correctly.
    @Test("concurrent calls are multiplexed by id", .timeLimit(.minutes(1)))
    func concurrentMultiplexing() async throws {
        let channel = FakeChannel { _, _, name in name.map { "result-for-\($0)" } }
        let client = MCPClient(transport: channel)
        try await client.connect()

        async let first = client.callTool("alpha", arguments: [:])
        async let second = client.callTool("beta", arguments: [:])
        let results = try await [first, second]

        #expect(results.contains("result-for-alpha"))
        #expect(results.contains("result-for-beta"))
        await client.disconnect()
    }

    /// A server that never answers must not hang the caller forever: the per-request
    /// deadline fires and the call throws.
    @Test("a request times out when the server never responds", .timeLimit(.minutes(1)))
    func requestTimeout() async throws {
        let channel = FakeChannel { _, _, _ in nil } // answers initialize only; never answers tools
        let client = MCPClient(transport: channel, requestTimeout: .milliseconds(200))
        try await client.connect()

        await #expect(throws: MCPClient.Failure.self) {
            _ = try await client.callTool("never", arguments: [:])
        }
        await client.disconnect()
    }
}

/// A fake `Transport.Channel`: parses each request's id+method and yields a crafted
/// JSON-RPC response. `responder(method, id, toolName) -> String?` returns the text
/// payload for a tools/call (nil = do not answer). `initialize` is always answered.
private final class FakeChannel: Transport.Channel, @unchecked Sendable {
    private let stream: AsyncThrowingStream<Data, Error>
    private let continuation: AsyncThrowingStream<Data, Error>.Continuation
    private let responder: @Sendable (_ method: String, _ id: Int, _ toolName: String?) -> String?

    init(responder: @escaping @Sendable (_ method: String, _ id: Int, _ toolName: String?) -> String?) {
        self.responder = responder
        var continuation: AsyncThrowingStream<Data, Error>.Continuation!
        stream = AsyncThrowingStream { continuation = $0 }
        self.continuation = continuation
    }

    var inbound: AsyncThrowingStream<Data, Error> {
        stream
    }

    func start() async throws {}
    func stop() async {
        continuation.finish()
    }

    func send(_ frame: Data) async throws {
        guard let object = try? JSONSerialization.jsonObject(with: frame) as? [String: Any],
              let id = object["id"] as? Int,
              let method = object["method"] as? String
        else { return }

        if method == "initialize" {
            continuation.yield(json(id: id, resultBody: #"{"protocolVersion":"test"}"#))
            return
        }
        let toolName = (object["params"] as? [String: Any])?["name"] as? String
        guard let text = responder(method, id, toolName) else { return }
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        continuation.yield(json(id: id, resultBody: #"{"content":[{"type":"text","text":"\#(escaped)"}]}"#))
    }

    private func json(id: Int, resultBody: String) -> Data {
        Data(#"{"jsonrpc":"2.0","id":\#(id),"result":\#(resultBody)}"#.utf8)
    }
}
