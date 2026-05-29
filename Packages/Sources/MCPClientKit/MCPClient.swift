import Foundation
import MCPClientAPI
import MCPCore
import TransportAPI

/// A transport-agnostic MCP client: speaks JSON-RPC (initialize / tools / resources)
/// over `any Transport.Channel`, reusing cupertino's cross-platform `MCPCore` wire
/// types. It conforms to `Client.MCP`, the dependency-free seam `Backend.LocalSubprocess`
/// depends on, translating between our `Client.Argument`/`String` payloads and the
/// MCPCore types at this boundary. We deliberately do not build on cupertino's
/// `MCP.Client`, which is stdio-hardcoded with no transport injection point.
///
/// Requests are **multiplexed by id**: many can be in flight at once (the actor can
/// be re-entered across `await`), so each response is routed to the waiter whose
/// request id it carries. A single consumer task owns the inbound iterator and
/// dispatches frames; each request also has a deadline so a stalled server cannot
/// hang a caller forever.
public actor MCPClient: Client.MCP {
    private let transport: any Transport.Channel
    private let clientName: String
    private let clientVersion: String
    private let requestTimeout: Duration

    private var requestID = 0
    private var pending: [Int: CheckedContinuation<Data, Error>] = [:]
    private var inbox: [Int: Data] = [:] // responses that arrived before their waiter parked
    private var deadlines: [Int: Task<Void, Never>] = [:]
    private var streamFailure: Error?
    private var consumer: Task<Void, Never>?

    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(
        transport: any Transport.Channel,
        clientName: String = "cupertino-desktop",
        clientVersion: String = "0.0.1",
        requestTimeout: Duration = .seconds(30),
    ) {
        self.transport = transport
        self.clientName = clientName
        self.clientVersion = clientVersion
        self.requestTimeout = requestTimeout
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        self.encoder = encoder
    }

    public func connect() async throws {
        try await transport.start()
        startConsuming(transport.inbound)
        try await initialize()
    }

    public func disconnect() async {
        consumer?.cancel()
        consumer = nil
        await transport.stop()
        failAll(with: Failure.notConnected)
    }

    public func callTool(_ name: String, arguments: [String: Client.Argument]) async throws -> String {
        let wireArgs = arguments.reduce(into: [String: MCP.Core.Protocols.AnyCodable]()) { result, pair in
            result[pair.key] = pair.value.anyCodable
        }
        let result = try await send(
            method: "tools/call",
            params: ToolCallParams(name: name, arguments: wireArgs),
            as: MCP.Core.Protocols.CallToolResult.self,
        )
        if result.isError == true {
            throw Failure.backend(Self.text(from: result.content))
        }
        return Self.text(from: result.content)
    }

    public func readResource(_ uri: String) async throws -> String {
        let result = try await send(
            method: "resources/read",
            params: URIParams(uri: uri),
            as: MCP.Core.Protocols.ReadResourceResult.self,
        )
        return Self.resourceText(from: result.contents)
    }

    // MARK: - Handshake

    private func initialize() async throws {
        let params = InitializeParams(
            protocolVersion: MCPProtocolVersion,
            capabilities: InitializeParams.Capabilities(),
            clientInfo: InitializeParams.ClientInfo(name: clientName, version: clientVersion),
        )
        _ = try await send(method: "initialize", params: params, as: InitializeAck.self)
    }

    // MARK: - JSON-RPC

    private func send<Result: Decodable>(
        method: String,
        params: some Codable & Sendable,
        as _: Result.Type,
    ) async throws -> Result {
        requestID += 1
        let id = requestID
        let request = MCP.Core.Protocols.Request(id: .int(id), method: method, params: params)
        let requestData = try encoder.encode(request)

        try await transport.send(requestData)
        let frame = try await response(for: id)

        if let failure = try? decoder.decode(MCP.Core.Protocols.JSONRPCError.self, from: frame), failure.id == .int(id) {
            throw Failure.backend(failure.error.message)
        }
        let response = try decoder.decode(MCP.Core.Protocols.JSONRPCResponse.self, from: frame)
        let resultData = try encoder.encode(response.result)
        return try decoder.decode(Result.self, from: resultData)
    }

    /// Await the response frame for `id`, honouring frames that arrived early and the
    /// per-request deadline.
    private func response(for id: Int) async throws -> Data {
        if let frame = inbox.removeValue(forKey: id) { return frame }
        if let streamFailure { throw streamFailure }
        return try await withCheckedThrowingContinuation { continuation in
            pending[id] = continuation
            deadlines[id] = Task { [weak self, requestTimeout] in
                try? await Task.sleep(for: requestTimeout)
                await self?.expire(id)
            }
        }
    }

    private func expire(_ id: Int) {
        deadlines[id] = nil
        guard let continuation = pending.removeValue(forKey: id) else { return }
        continuation.resume(throwing: Failure.transport("request \(id) timed out"))
    }

    // MARK: - Inbound dispatch

    /// One task owns the iterator (so it never crosses an actor `await`) and routes
    /// each frame to the waiter whose id it carries.
    private func startConsuming(_ stream: AsyncThrowingStream<Data, Error>) {
        consumer = Task { [weak self] in
            do {
                for try await frame in stream {
                    await self?.route(.success(frame))
                }
                await self?.route(.failure(Failure.transport("connection closed")))
            } catch {
                await self?.route(.failure(error))
            }
        }
    }

    private func route(_ result: Result<Data, Error>) {
        switch result {
        case let .success(frame):
            guard let id = Self.frameID(frame) else { return } // notification or unkeyed; ignore
            deadlines[id]?.cancel()
            deadlines[id] = nil
            if let continuation = pending.removeValue(forKey: id) {
                continuation.resume(returning: frame)
            } else {
                inbox[id] = frame
            }
        case let .failure(error):
            failAll(with: error)
        }
    }

    private func failAll(with error: Error) {
        streamFailure = error
        for task in deadlines.values {
            task.cancel()
        }
        deadlines.removeAll()
        let waiters = pending
        pending.removeAll()
        inbox.removeAll()
        for continuation in waiters.values {
            continuation.resume(throwing: error)
        }
    }

    private static func frameID(_ frame: Data) -> Int? {
        guard let envelope = try? JSONDecoder().decode(Envelope.self, from: frame),
              case let .int(id) = envelope.id
        else { return nil }
        return id
    }

    // MARK: - Extraction

    private static func text(from blocks: [MCP.Core.Protocols.ContentBlock]) -> String {
        blocks.compactMap { block in
            if case let .text(content) = block { content.text } else { nil }
        }
        .joined(separator: "\n")
    }

    private static func resourceText(from contents: [MCP.Core.Protocols.ResourceContents]) -> String {
        contents.compactMap { content in
            if case let .text(text) = content { text.text } else { nil }
        }
        .joined(separator: "\n")
    }

    public enum Failure: Error, Sendable {
        case notConnected
        case transport(String)
        case backend(String)
    }

    // MARK: - Wire param shapes (our minimal Codable structs; the server only sees JSON)

    private struct Envelope: Decodable {
        let id: MCP.Core.Protocols.RequestID?
    }

    private struct ToolCallParams: Codable {
        let name: String
        let arguments: [String: MCP.Core.Protocols.AnyCodable]
    }

    private struct URIParams: Codable {
        let uri: String
    }

    private struct InitializeParams: Codable {
        let protocolVersion: String
        let capabilities: Capabilities
        let clientInfo: ClientInfo
        struct Capabilities: Codable {}
        struct ClientInfo: Codable {
            let name: String
            let version: String
        }
    }

    private struct InitializeAck: Decodable {}
}

private extension Client.Argument {
    var anyCodable: MCP.Core.Protocols.AnyCodable {
        switch self {
        case let .string(value): MCP.Core.Protocols.AnyCodable(value)
        case let .int(value): MCP.Core.Protocols.AnyCodable(value)
        case let .bool(value): MCP.Core.Protocols.AnyCodable(value)
        }
    }
}
