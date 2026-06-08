public extension Presentation {
    /// A reusable async presentation state for data that native shells render in
    /// their own framework.
    enum LoadState<Value: Sendable>: Sendable {
        case idle
        case loading
        case loaded(Value)
        case failed(String)
    }
}
