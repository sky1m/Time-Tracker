import SwiftUI
import SwiftData

@main
struct BreakPlannerApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: TransitTheme.Appearance = .light
    @StateObject private var activityCoordinator = BreakActivityCoordinator()

    var body: some Scene {
        WindowGroup {
            ActivityReconciliationView()
                .environmentObject(activityCoordinator)
                .preferredColorScheme(appearanceMode.colorScheme)
        }
        // Forms explicitly save after validation and restore edits on failure.
        .modelContainer(for: [Employee.self, Shift.self], isAutosaveEnabled: false)
    }
}

private struct ActivityReconciliationView: View {
    @EnvironmentObject private var activityCoordinator: BreakActivityCoordinator
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TeamScheduleView()
            .task { await reconcileSavedShifts() }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await reconcileSavedShifts() }
            }
    }

    private func reconcileSavedShifts() async {
        // A failed fetch must not be mistaken for an empty roster.
        guard let shifts = try? modelContext.fetch(FetchDescriptor<Shift>()) else { return }
        await activityCoordinator.reconcile(shifts: shifts)
    }
}
