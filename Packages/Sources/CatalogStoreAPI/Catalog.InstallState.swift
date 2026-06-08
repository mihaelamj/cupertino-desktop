public extension Catalog {
    /// Coarse catalog lifecycle states that UI shells can render without knowing
    /// storage layout, resource file names, or SQLite details.
    enum InstallState: Sendable, Equatable, CaseIterable {
        case notInstalled
        case downloading
        case verifying
        case installing
        case ready
        case updateAvailable
        case failed
        case removing
    }
}
