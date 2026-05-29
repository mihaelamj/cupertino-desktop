import Foundation

public extension Transport {
    /// Moves one JSON-RPC frame at a time between `MCPClient` and a server.
    /// Conformers: `Transport.Subprocess` (stdio to `cupertino serve`, macOS)
    /// and, later, a remote HTTP/SSE transport. Frames are raw `Data`; the
    /// client owns encoding/decoding.
    protocol Channel: Sendable {
        /// Bring the transport up (spawn the process, open the connection).
        func start() async throws

        /// Tear it down and release resources.
        func stop() async

        /// Send one encoded JSON-RPC frame.
        func send(_ frame: Data) async throws

        /// Inbound frames from the server, one per element.
        var inbound: AsyncThrowingStream<Data, Error> { get }
    }
}
