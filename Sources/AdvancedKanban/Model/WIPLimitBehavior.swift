/// Controls what happens when a drop would put a column over its
/// `wipLimit`.
public enum WIPLimitBehavior: Sendable, Equatable {
    /// The drop always succeeds; the column renders warning styling while
    /// over limit. Default.
    case warnOnly

    /// A drop that would exceed the limit is rejected; the dragged card
    /// animates back to its origin.
    case preventDrop
}
