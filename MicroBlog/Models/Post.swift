import Foundation

/// A user's post for one calendar day. Each post holds an ordered list of
/// `Collage`s; viewers swipe horizontally between them and read each one's
/// text body below the canvas.
struct Post: Identifiable, Hashable, Sendable {
    let id: UUID
    let authorId: UUID
    /// Start-of-day in the user's local calendar.
    let day: Date
    var collages: [Collage]
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        authorId: UUID,
        day: Date,
        collages: [Collage] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.day = Calendar.current.startOfDay(for: day)
        self.collages = collages
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var isEmpty: Bool { collages.isEmpty }
}

extension Date {
    var dayKey: Date { Calendar.current.startOfDay(for: self) }

    /// "Today" / "Yesterday" / "MMM d".
    var pageDateLabel: String {
        let cal = Calendar.current
        if cal.isDateInToday(self) { return "Today" }
        if cal.isDateInYesterday(self) { return "Yesterday" }
        let f = DateFormatter()
        if cal.isDate(self, equalTo: Date(), toGranularity: .year) {
            f.dateFormat = "MMM d"
        } else {
            f.dateFormat = "MMM d, yyyy"
        }
        return f.string(from: self)
    }
}
