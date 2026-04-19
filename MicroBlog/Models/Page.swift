import Foundation
import SwiftUI

/// One scrapbook page. Each user has at most one page per calendar day.
struct Page: Identifiable, Hashable, Sendable {
    let id: UUID
    let authorId: UUID
    /// The day this page belongs to, normalized to start-of-day in the user's local calendar.
    let day: Date
    var theme: PageTheme
    /// All elements on the page, including reactions placed by other users.
    var elements: [PageElement]
    var createdAt: Date
    var updatedAt: Date

    /// The page canvas's intrinsic aspect ratio (width / height).
    static let aspectRatio: CGFloat = 3.0 / 4.0

    init(
        id: UUID = UUID(),
        authorId: UUID,
        day: Date,
        theme: PageTheme = .warmPaper,
        elements: [PageElement] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.authorId = authorId
        self.day = Calendar.current.startOfDay(for: day)
        self.theme = theme
        self.elements = elements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Elements created by the page owner (excludes reactions).
    var ownElements: [PageElement] {
        elements.filter { $0.authorId == authorId }
    }

    /// Reactions = elements not authored by the page owner.
    var reactions: [PageElement] {
        elements.filter { $0.authorId != authorId }
    }
}

extension Date {
    var dayKey: Date { Calendar.current.startOfDay(for: self) }

    /// "Apr 18" for the feed grid; "Today" / "Yesterday" otherwise.
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
