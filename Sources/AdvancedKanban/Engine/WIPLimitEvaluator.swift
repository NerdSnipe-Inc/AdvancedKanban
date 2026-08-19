/// The outcome of checking a candidate drop against a column's WIP limit.
public enum WIPLimitDropDecision: Equatable {
    case accept
    case acceptWithWarning
    case reject
}

public enum WIPLimitEvaluator {
    /// - Parameters:
    ///   - destinationCardCount: The destination column's current card
    ///     count, *before* the move is applied.
    ///   - isMovingWithinSameColumn: `true` when source and destination
    ///     column are the same — the moving card is already included in
    ///     `destinationCardCount`, so it must not be counted again.
    public static func evaluate(
        destinationCardCount: Int,
        wipLimit: Int?,
        behavior: WIPLimitBehavior,
        isMovingWithinSameColumn: Bool
    ) -> WIPLimitDropDecision {
        guard let wipLimit else { return .accept }

        let effectiveCount = isMovingWithinSameColumn ? destinationCardCount : destinationCardCount + 1
        guard effectiveCount > wipLimit else { return .accept }

        switch behavior {
        case .warnOnly: return .acceptWithWarning
        case .preventDrop: return .reject
        }
    }
}
