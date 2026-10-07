import SwiftUI
import SwiftData

struct TeamScheduleView: View {
    @AppStorage("appearanceMode") private var appearanceMode: TransitTheme.Appearance = .light
    @Query(sort: \Employee.name) private var employees: [Employee]
    @Query(sort: \Shift.startsAt) private var shifts: [Shift]
    @State private var selectedWorkday = WorkdayDate.localCalendar.startOfDay(for: .now)
    @State private var presentedForm: PresentedForm?
    @EnvironmentObject private var activityCoordinator: BreakActivityCoordinator
    @Environment(\.scenePhase) private var scenePhase
    @State private var timelineStart = Date.now

    private enum PresentedForm: Identifiable {
        case employee(Employee?)
        case shift(Employee, Shift?, Date)

        var id: String {
            switch self {
            case .employee(let employee):
                return "employee-\(employee?.id.uuidString ?? "new")"
            case .shift(let employee, let shift, _):
                return "shift-\(employee.id)-\(shift?.id.uuidString ?? "new")"
            }
        }
    }

    private var workdayShifts: [Shift] {
        shifts.filter { WorkdayDate.matches($0.workday, localDate: selectedWorkday) }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Workday", selection: $selectedWorkday, displayedComponents: .date)
                }
                .listRowBackground(TransitTheme.surface)
                Section("Appearance") {
                    Picker("Appearance", selection: $appearanceMode) {
                        ForEach(TransitTheme.Appearance.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .listRowBackground(TransitTheme.surface)
                if employees.isEmpty {
                    ContentUnavailableView("No Employees", systemImage: "person.2", description: Text("Add an employee to start planning shifts."))
                        .listRowBackground(TransitTheme.surface)
                } else {
                    Section("Team") {
                        if workdayShifts.isEmpty {
                            Text("No shifts for this workday. Add a shift for an employee below.").foregroundStyle(TransitTheme.secondaryText)
                        }
                        ForEach(employees) { employee in employeeRow(employee) }
                    }
                    .listRowBackground(TransitTheme.surface)
                }
                Section {
                    Button {
                        presentedForm = .employee(nil)
                    } label: {
                        Label("Add Employee", systemImage: "person.badge.plus")
                    }
                }
                .listRowBackground(TransitTheme.surface)
            }
            .transitScreenStyle()
            .navigationTitle("Break Planner")
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { timelineStart = .now }
            }
            .sheet(item: $presentedForm) { form in
                switch form {
                case .employee(let employee):
                    EmployeeFormView(employee: employee, onSaved: {})
                case .shift(let employee, let shift, let day):
                    ShiftFormView(employee: employee, shift: shift, workday: day, onSaved: {})
                }
            }
        }
        .environment(\.calendar, WorkdayDate.localCalendar)
    }

    private func employeeRow(_ employee: Employee) -> some View {
        let shift = workdayShifts.first { $0.employee?.id == employee.id }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(employee.name).font(.headline)
                Spacer()
                Button("Edit Employee") { presentedForm = .employee(employee) }
                    .font(.caption)
                    .buttonStyle(.borderless)
            }
            if let shift {
                Text("\(shift.startsAt.formatted(date: .omitted, time: .shortened)) – \(shift.endsAt.formatted(date: .omitted, time: .shortened))")
                if !Calendar.current.isDate(shift.startsAt, inSameDayAs: shift.endsAt) {
                    Text("Ends the following day").font(.caption).foregroundStyle(TransitTheme.secondaryText)
                }
                NavigationLink {
                    ShiftRouteView(shift: shift)
                } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("View Route", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        TimelineView(.periodic(from: timelineStart, by: 1)) { context in
                            ShiftCountdownSummary(state: ShiftCountdown.state(
                                for: ShiftInterval(startsAt: shift.startsAt, endsAt: shift.endsAt),
                                now: context.date
                            ))
                        }
                        .id(timelineStart)
                    }
                }
                if let message = activityCoordinator.resultsByShiftID[shift.id]?.rosterMessage {
                    Label(message, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(TransitTheme.secondaryText)
                }
                Button("Edit Shift") { presentedForm = .shift(employee, shift, selectedWorkday) }
                    .buttonStyle(.borderless)
            } else {
                Text("No shift assigned").foregroundStyle(TransitTheme.secondaryText)
                Button("Add Shift") { presentedForm = .shift(employee, nil, selectedWorkday) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
