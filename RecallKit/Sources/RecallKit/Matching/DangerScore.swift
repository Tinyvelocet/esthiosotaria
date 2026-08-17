import Foundation

/// A continuous 0...1 aggregate danger score for a store, computed from
/// its currently active (chain-matched) recalls. Distinct from the
/// per-recall `Recall.Classification`, which stays a discrete Class I/II/III
/// label wherever an individual recall is shown — this is only for
/// summarizing "how concerning is this store right now" at a glance,
/// e.g. on a dashboard tile.
public enum DangerScore {

    /// The worst single recall dominates the score (a store with one
    /// Class I recall reads as more dangerous than a store with three
    /// Class III recalls), with a small boost for having multiple active
    /// recalls so a busy store isn't visually identical to a quiet one.
    public static func score(for recalls: [Recall]) -> Double {
        guard !recalls.isEmpty else { return 0 }
        let worst = recalls.map(weight(for:)).max() ?? 0
        let countBoost = min(Double(recalls.count - 1) * 0.08, 0.2)
        return min(worst + countBoost, 1.0)
    }

    private static func weight(for recall: Recall) -> Double {
        switch recall.classification {
        case .classI: return 1.0
        case .classII: return 0.55
        case .classIII: return 0.25
        case .unknown, nil: return 0.15
        }
    }
}
