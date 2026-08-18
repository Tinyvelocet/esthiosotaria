import Foundation

/// Which recalls are serious enough to interrupt with a notification (or
/// earn a place in a default-visible surface) versus ones that should
/// stay quietly available in a list. Class I (serious/death risk) and
/// Class II (moderate risk) qualify; Class III ("unlikely harm") and
/// unclassified recalls don't — notification fatigue from minor recalls
/// is itself a safety problem, since it trains people to dismiss the one
/// that matters.
public enum AlertPolicy {
    public static func warrantsNotification(_ recall: Recall) -> Bool {
        switch recall.classification {
        case .classI, .classII: return true
        case .classIII, .unknown, nil: return false
        }
    }
}
