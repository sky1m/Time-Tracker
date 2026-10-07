import ActivityKit
import Foundation

struct BreakActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        let eventTitle: String
        let eventLetter: String?
        let eventKind: String?
        let eventStartsAt: Date
        let eventEndsAt: Date
    }

    let employeeID: UUID
    let shiftID: UUID
    let employeeName: String
    let shiftStartsAt: Date
    let shiftEndsAt: Date
}
