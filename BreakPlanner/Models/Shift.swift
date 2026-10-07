import Foundation
import SwiftData

@Model
final class Shift {
    @Attribute(.unique) var id: UUID
    // Preserve the selected workday even when the shift crosses midnight.
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
