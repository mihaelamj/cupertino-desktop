import AppCore
import AppModels
import BackendAPI
import Foundation
import Observation

public extension Feature.FrameworkBrowser {
    /// The framework sidebar's view model: loads `listFrameworks()` and exposes the
    /// result as a single `state` enum that both UI shells bind to. It is the
    /// framework-agnostic seam, SwiftUI and AppKit render it identically and differ
    /// only in view code (docs/DESIGN.md, the parallel seam-discovery note).
    ///
    /// It depends on the **narrow** backend slices it uses (`Connecting`,
    /// `FrameworkBrowsing`), not the whole `Backend.Documentation`, so a test can
    /// inject a tiny fake with no transport.
    @Observable
    @MainActor
    final class ViewModel {
        /// Single source of truth for the load. An enum keeps invalid combinations
        /// (loading AND failed) unrepresentable (docs/rules/view-models.md).
        public enum LoadState: Sendable {
            case idle
            case loading
            case loaded([Model.Framework])
            case failed(String)
        }

        public private(set) var state: LoadState = .idle

        /// The loaded frameworks, or empty in any other state. Derived, never stored
        /// alongside `state`.
        public var frameworks: [Model.Framework] {
            if case let .loaded(frameworks) = state { frameworks } else { [] }
        }

        public var isLoading: Bool {
            if case .loading = state { true } else { false }
        }

        public var errorMessage: String? {
            if case let .failed(message) = state { message } else { nil }
        }

        private let backend: any Backend.Connecting & Backend.FrameworkBrowsing
        private var loadTask: Task<Void, Never>?

        public init(backend: any Backend.Connecting & Backend.FrameworkBrowsing) {
            self.backend = backend
        }

        /// Load the list once, on the view's first appearance. Connecting the backend
        /// happens here only because this is the single feature that talks to it; the
        /// connect lifecycle is the seam to lift into a shared coordinator when a
        /// second feature appears (docs/DESIGN.md). The task holds `self` weakly, so a
        /// dismissed view's in-flight load cannot keep the model alive.
        public func onAppeared() {
            guard case .idle = state else { return }
            loadTask = Task { [weak self] in await self?.load() }
        }

        /// Re-run after a failure (a Retry affordance in the views).
        public func onRetried() {
            loadTask?.cancel()
            state = .idle
            onAppeared()
        }

        /// Internal (not private) so a test can drive the load deterministically via
        /// `@testable import` without depending on task-scheduling timing.
        func load() async {
            state = .loading
            do {
                try await backend.connect()
                let frameworks = try await backend.listFrameworks()
                if Task.isCancelled { return }
                state = .loaded(frameworks)
            } catch {
                if Task.isCancelled { return }
                state = .failed(error.localizedDescription)
            }
        }
    }
}
