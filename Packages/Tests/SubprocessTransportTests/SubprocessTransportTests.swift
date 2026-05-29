#if os(macOS)
    import Foundation
    @testable import SubprocessTransport
    import Testing
    import TransportAPI

    @Suite("SubprocessTransport")
    struct SubprocessTransportTests {
        /// Round-trip framing without any MCP: `/bin/cat` echoes stdin to stdout, so
        /// frames we `send` come back as newline-delimited `inbound` frames. This
        /// proves the spawn, pipe wiring, and line framing independently of cupertino.
        @Test("frames round-trip through a spawned process")
        func framingRoundTrip() async throws {
            let transport = Transport.Subprocess(command: "/bin/cat", arguments: [])
            try await transport.start()

            var iterator = transport.inbound.makeAsyncIterator()
            try await transport.send(Data("hello".utf8))
            try await transport.send(Data("world".utf8))

            let first = try await iterator.next()
            let second = try await iterator.next()
            #expect(first.flatMap { String(data: $0, encoding: .utf8) } == "hello")
            #expect(second.flatMap { String(data: $0, encoding: .utf8) } == "world")

            await transport.stop()
        }

        @Test("sending before start fails honestly")
        func sendBeforeStartThrows() async {
            let transport = Transport.Subprocess(command: "/bin/cat", arguments: [])
            await #expect(throws: (any Error).self) {
                try await transport.send(Data("x".utf8))
            }
        }

        /// When the spawned process exits (EOF on stdout), the inbound stream must
        /// finish so waiters fail fast instead of hanging. `/bin/echo hi` prints one
        /// line and exits.
        @Test("inbound stream finishes when the process exits", .timeLimit(.minutes(1)))
        func streamFinishesOnExit() async throws {
            let transport = Transport.Subprocess(command: "/bin/echo", arguments: ["hi"])
            try await transport.start()
            var iterator = transport.inbound.makeAsyncIterator()
            let first = try await iterator.next()
            #expect(first.flatMap { String(data: $0, encoding: .utf8) } == "hi")
            // After the single line, the process exits and the stream ends.
            let next = try await iterator.next()
            #expect(next == nil)
            await transport.stop()
        }
    }
#endif
