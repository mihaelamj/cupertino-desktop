#if os(macOS)
    import Foundation
    import MCPTransportAPI

    public extension Transport {
        /// A `Channel` that launches `cupertino serve` and frames JSON-RPC over its
        /// stdio pipes (newline-delimited). macOS only: iOS forbids spawning
        /// subprocesses, which is precisely why iOS uses the embedded backend
        /// instead (docs/DESIGN.md section 5.3).
        ///
        /// Process spawning, pipe wiring, and forwarding stdout lines into
        /// `inbound` land in milestone M1; this scaffold fixes the shape.
        final class Subprocess: Channel, @unchecked Sendable {
            private let command: String
            private let arguments: [String]
            private let stream: AsyncThrowingStream<Data, Error>
            private let continuation: AsyncThrowingStream<Data, Error>.Continuation

            public init(command: String, arguments: [String]) {
                self.command = command
                self.arguments = arguments
                var continuation: AsyncThrowingStream<Data, Error>.Continuation!
                stream = AsyncThrowingStream { continuation = $0 }
                self.continuation = continuation
            }

            public nonisolated var inbound: AsyncThrowingStream<Data, Error> {
                stream
            }

            public func start() async throws {
                // M1: spawn `command + arguments`, wire stdin/stdout pipes, and
                // forward each newline-delimited stdout frame into `continuation`.
                throw Failure.notImplemented
            }

            public func stop() async {
                continuation.finish()
            }

            public func send(_: Data) async throws {
                throw Failure.notImplemented
            }

            public enum Failure: Error, Sendable {
                case notImplemented
            }
        }
    }
#endif
