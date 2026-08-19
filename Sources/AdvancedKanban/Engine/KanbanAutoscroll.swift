import CoreGraphics

/// Which way, and how fast, a scroll container should autoscroll while a
/// drag's pointer sits near its edge.
public enum KanbanAutoscrollDirection: Equatable {
    case none
    case negative(magnitude: CGFloat)
    case positive(magnitude: CGFloat)
}

public enum KanbanAutoscrollCalculator {
    /// `edgeBand` is the distance in points from either edge of `bounds`
    /// within which autoscroll engages. Speed ramps linearly from 0 at the
    /// band's inner boundary to `maxSpeed` at the outer edge itself.
    public static func direction(
        pointerPosition: CGFloat,
        bounds: ClosedRange<CGFloat>,
        edgeBand: CGFloat,
        maxSpeed: CGFloat
    ) -> KanbanAutoscrollDirection {
        guard edgeBand > 0 else { return .none }
        guard bounds.contains(pointerPosition) else { return .none }

        let lowerBandEdge = bounds.lowerBound + edgeBand
        let upperBandEdge = bounds.upperBound - edgeBand

        if pointerPosition < lowerBandEdge {
            let proximity = (lowerBandEdge - pointerPosition) / edgeBand
            return .negative(magnitude: maxSpeed * min(proximity, 1))
        }
        if pointerPosition > upperBandEdge {
            let proximity = (pointerPosition - upperBandEdge) / edgeBand
            return .positive(magnitude: maxSpeed * min(proximity, 1))
        }
        return .none
    }
}
