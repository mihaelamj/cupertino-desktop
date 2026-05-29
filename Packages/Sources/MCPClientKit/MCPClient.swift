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
/// Requests are serialized by the actor and answered FIFO: one request is in flight
/// at a time, so the next inbound frame matching our id is its response.
public actor MCPClient: Client.MCP {
    private let transport: any Transport.Channel
    private let clientName: String
    private let clientVersion: String

    private var requestID = 0
    private var pending: CheckedContinuation<Data, Error>?
    private var buffered: [Data] = []
    private var streamError: Error?
    private var consumer: Task<Void, Never>?
    private let encoder: JSONEncoder
    private let decoder = JSONDecoder()

    public init(transport: any Transport.Channel, clientName: String = "cupertino-desktop", clientVersion: String = "0.0.1") {
        self.transport = transport
        self.clientName = clientName
        self.clientVersion = clientVersion
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
        pending?.resume(throwing: Failure.notConnected)
        pending = nil
        buffered.removeAll()
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
        try await transport.send(encoder.encode(request))

        while true {
            let frame = try await nextFrame()
            if let failure = try? decoder.decode(MCP.Core.Protocols.JSONRPCError.self, from: frame), failure.id == .int(id) {
                throw Failure.backend(failure.error.message)
            }
            guard let response = try? decoder.decode(MCP.Core.Protocols.JSONRPCResponse.self, from: frame),
                  response.id == .int(id)
            else {
                continue // a notification or an unrelated frame; keep reading
            }
            let resultData = try encoder.encode(response.result)
            return try decoder.decode(Result.self, from: resultData)
        }
    }

    /// A single task owns the inbound iterator (so it never crosses an actor `await`)
    /// and hands each frame to the parked reader, FIFO.
    private func startConsuming(_ stream: AsyncThrowingStream<Data, Error>) {
        consumer = Task { [weak self] in
            do {
                for try await frame in stream {
                    await self?.deliver(.success(frame))
                }
                await self?.deliver(.failure(Failure.transport("connection closed")))
            } catch {
                await self?.deliver(.failure(error))
            }
        }
    }

    private func deliver(_ result: Result<Data, Error>) {
        if let pending {
            self.pending = nil
            pending.resume(with: result)
            return
        }
        switch result {
        case let .success(frame): buffered.append(frame)
        case let .failure(error): streamError = error
        }
    }

    private func nextFrame() async throws -> Data {
        if !buffered.isEmpty { return buffered.removeFirst() }
        if let streamError {
            self.streamError = nil
            throw streamError
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending = continuation
        }
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
