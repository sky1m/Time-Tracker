import SwiftUI
import SwiftData

struct TeamScheduleView: View {
    @Query(sort: \Employee.name) private var employees: [Employee]
    @Query(sort: \Shift.startsAt) private var shifts: [Shift]
    @State private var selectedWorkday = Calendar.current.startOfDay(for: .now)
    @State private var presentedForm: PresentedForm?

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
        let calendar = Calendar.current
        let day = calendar.startOfDay(for: selectedWorkday)
        return shifts.filter { calendar.startOfDay(for: $0.workday) == day }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    DatePicker("Workday", selection: $selectedWorkday, displayedComponents: .date)
                }
                if employees.isEmpty {
                    ContentUnavailableView("No Employees", systemImage: "person.2", description: Text("Add an employee to start planning shifts."))
                } else {
                    if workdayShifts.isEmpty {
                        Section {
                            Text("No shifts for this workday. Add a shift for an employee below.").foregroundStyle(.secondary)
                        }
                    }
                    Section("Team") {
                        ForEach(employees) { employee in employeeRow(employee) }
                    }
                }
                Section {
                    Button {
                        presentedForm = .employee(nil)
                    } label: {
                        Label("Add Employee", systemImage: "person.badge.plus")
                    }
                }
            }
            .navigationTitle("Break Planner")
            .sheet(item: $presentedForm) { form in
                switch form {
                case .employee(let employee):
                    EmployeeFormView(employee: employee, onSaved: {})
                case .shift(let employee, let shift, let day):
                    ShiftFormView(employee: employee, shift: shift, workday: day, onSaved: {})
                }
            }
        }
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
                    Text("Ends the following day").font(.caption).foregroundStyle(.secondary)
                }
                Button("Edit Shift") { presentedForm = .shift(employee, shift, selectedWorkday) }
                    .buttonStyle(.borderless)
            } else {
                Text("No shift assigned").foregroundStyle(.secondary)
                Button("Add Shift") { presentedForm = .shift(employee, nil, selectedWorkday) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 4)
    }
}
