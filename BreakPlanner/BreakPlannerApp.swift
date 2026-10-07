import SwiftUI
import SwiftData

@main
struct BreakPlannerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: TransitTheme.Appearance = .light

    var body: some Scene {
        WindowGroup {
            TeamScheduleView()
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        // Forms explicitly save after validation and restore edits on failure.
        .modelContainer(for: [Employee.self, Shift.self], isAutosaveEnabled: false)
    }
}
