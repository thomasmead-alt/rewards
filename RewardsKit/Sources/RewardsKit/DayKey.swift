import Foundation

/// Day keys are "yyyy-MM-dd" strings in the user's calendar/timezone.
/// They compare lexicographically in date order.
public enum DayKey {
    public static func key(for date: Date, calendar: Calendar) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    public static func yesterdayKey(for date: Date, calendar: Calendar) -> String {
        let yesterday = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        return key(for: yesterday, calendar: calendar)
    }
}
