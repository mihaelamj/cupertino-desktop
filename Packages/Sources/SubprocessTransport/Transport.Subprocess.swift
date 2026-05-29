#if os(macOS)
    import Foundation
    import TransportAPI

    public extension Transport {
        /// A `Channel` that launches a command (here, `cupertino serve`) and frames
        /// JSON-RPC over its stdio pipes, newline-delimited. macOS only: iOS forbids
        /// spawning subprocesses, which is why iOS uses the embedded adapter instead
        /// (docs/DESIGN.md section 5.3). Cupertino itself never appears here: this is
        /// a generic line-framed process transport that happens to carry MCP frames.
        final class Subprocess: Channel, @unchecked Sendable {
            private let command: String
            private let arguments: [String]
            private let stream: AsyncThrowingStream<Data, Error>
            private let continuation: AsyncThrowingStream<Data, Error>.Continuation

            private let lock = NSLock()
            private var process: Process?
            private var stdin: FileHandle?
            private var inboundBuffer = Data()

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
                let process = Process()
                let stdinPipe = Pipe()
                let stdoutPipe = Pipe()
                let stderrPipe = Pipe()

                // Resolve the executable: absolute path runs directly, otherwise go
                // through `env` so a `PATH` lookup finds the brew-installed binary.
                if command.hasPrefix("/") {
                    process.executableURL = URL(fileURLWithPath: command)
                    process.arguments = arguments
                } else {
                    process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
                    process.arguments = [command] + arguments
                }
                process.standardInput = stdinPipe
                process.standardOutput = stdoutPipe
                process.standardError = stderrPipe

                stdoutPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                    let data = handle.availableData
                    guard !data.isEmpty else { return }
                    self?.ingest(data)
                }

                do {
                    try process.run()
                } catch {
                    continuation.finish(throwing: Failure.spawnFailed(error.localizedDescription))
                    throw Failure.spawnFailed(error.localizedDescription)
                }

                self.process = process
                stdin = stdinPipe.fileHandleForWriting
            }

            public func send(_ frame: Data) async throws {
                guard let stdin else { throw Failure.notStarted }
                // MCP stdio frames are one JSON object per line; strip any embedded
                // newlines and terminate with exactly one.
                var line = Data(frame.filter { $0 != 0x0A })
                line.append(0x0A)
                do {
                    try stdin.write(contentsOf: line)
                } catch {
                    throw Failure.writeFailed(error.localizedDescription)
                }
            }

            public func stop() async {
                process?.terminate()
                stdin = nil
                process = nil
                continuation.finish()
            }

            /// Buffer raw stdout bytes and yield each complete newline-delimited
            /// frame. Runs on the pipe's background queue; serialized by `lock`.
            private func ingest(_ data: Data) {
                lock.lock()
                defer { lock.unlock() }
                inboundBuffer.append(data)
                while let newline = inboundBuffer.firstIndex(of: 0x0A) {
                    let line = inboundBuffer.subdata(in: inboundBuffer.startIndex ..< newline)
                    inboundBuffer.removeSubrange(inboundBuffer.startIndex ... newline)
                    if !line.isEmpty {
                        continuation.yield(line)
                    }
                }
            }

            public enum Failure: Error, Sendable {
                case notStarted
                case spawnFailed(String)
                case writeFailed(String)
            }
        }
    }
#endif
