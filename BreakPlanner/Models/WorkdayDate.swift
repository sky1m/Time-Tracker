import Foundation

/// Stores a Gregorian civil date at UTC noon, independent of the device time zone.
enum WorkdayDate {
    static var localCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    private static var storageCalendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    static func storedDate(fromLocal date: Date, calendar: Calendar = localCalendar) -> Date {
        let civilDate = calendar.dateComponents([.era, .year, .month, .day], from: date)
        return storageCalendar.date(from: noonComponents(for: civilDate))!
    }

    /// Reconstructs the stored civil date in the device's local calendar for UI use.
    static func localDate(fromStored date: Date, calendar: Calendar = localCalendar) -> Date {
        let civilDate = storageCalendar.dateComponents([.era, .year, .month, .day], from: date)
        return calendar.date(from: noonComponents(for: civilDate))!
    }

    static func matches(_ storedDate: Date, localDate: Date, calendar: Calendar = localCalendar) -> Bool {
        let stored = storageCalendar.dateComponents([.era, .year, .month, .day], from: storedDate)
        let local = calendar.dateComponents([.era, .year, .month, .day], from: localDate)
        return stored.era == local.era && stored.year == local.year &&
            stored.month == local.month && stored.day == local.day
    }

    private static func noonComponents(for civilDate: DateComponents) -> DateComponents {
        var components = DateComponents()
        components.era = civilDate.era
        components.year = civilDate.year
        components.month = civilDate.month
        components.day = civilDate.day
        components.hour = 12
        return components
    }
}
