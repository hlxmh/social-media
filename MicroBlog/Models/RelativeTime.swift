import Foundation

enum RelativeTime {
    static func string(from date: Date, relativeTo now: Date = Date()) -> String {
        let interval = now.timeIntervalSince(date)
        switch interval {
        case ..<60: return "now"
        case ..<3_600: return "\(Int(interval / 60))m"
        case ..<86_400: return "\(Int(interval / 3_600))h"
        case ..<604_800: return "\(Int(interval / 86_400))d"
        default:
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: date)
        }
    }
}
