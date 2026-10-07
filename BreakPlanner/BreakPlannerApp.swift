import SwiftUI
import SwiftData

@main
struct BreakPlannerApp: App {
    var body: some Scene {
        WindowGroup {
            TeamScheduleView()
        }
        // Forms explicitly save after validation and restore edits on failure.
        .modelContainer(for: [Employee.self, Shift.self], isAutosaveEnabled: false)
    }
}
