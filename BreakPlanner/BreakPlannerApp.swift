import SwiftUI
import SwiftData

@main
struct BreakPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            TeamScheduleView()
        }
        .modelContainer(for: [Employee.self, Shift.self])
    }
}
