import Foundation
import SwiftData

@Model
final class Shift {
    @Attribute(.unique) var id: UUID
    // Gregorian civil workday encoded at UTC noon by WorkdayDate.
    var workday: Date
    var startsAt: Date
    var endsAt: Date
    var employee: Employee?

    init(
        id: UUID = UUID(),
        workday: Date,
        startsAt: Date,
        endsAt: Date,
        employee: Employee? = nil
    ) {
        self.id = id
        self.workday = workday
        self.startsAt = startsAt
        self.endsAt = endsAt
        self.employee = employee
    }
}
