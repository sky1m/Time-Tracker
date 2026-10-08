import SwiftUI
import SwiftData

struct ShiftFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var activityCoordinator: BreakActivityCoordinator
    private let employee: Employee
    private let shift: Shift?
    private let onSaved: () -> Void
    @State private var workday: Date
    @State private var startTime: Date
    @State private var endTime: Date
    @State private var errorMessage: String?
    @State private var confirmsDeletion = false

    init(employee: Employee, shift: Shift?, workday: Date, onSaved: @escaping () -> Void) {
        self.employee = employee
        self.shift = shift
        self.onSaved = onSaved
        let calendar = WorkdayDate.localCalendar
        let localWorkday = shift.map { WorkdayDate.localDate(fromStored: $0.workday, calendar: calendar) } ?? workday
        let day = calendar.startOfDay(for: localWorkday)
        _workday = State(initialValue: day)
        _startTime = State(initialValue: shift?.startsAt ?? calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day)
        _endTime = State(initialValue: shift?.endsAt ?? calendar.date(bySettingHour: 17, minute: 0, second: 0, of: day) ?? day)
    }

    private var startMinutes: Int { clockMinutes(startTime) }
    private var endMinutes: Int { clockMinutes(endTime) }

    var body: some View {
        NavigationStack {
            Form {
                Section(employee.name) {
                    DatePicker("Workday", selection: $workday, displayedComponents: .date)
                    DatePicker("Start", selection: $startTime, displayedComponents: .hourAndMinute)
                    DatePicker("End", selection: $endTime, displayedComponents: .hourAndMinute)
                }
                .listRowBackground(TransitTheme.surface)
                Section {
                    if startMinutes == endMinutes {
                        Text("Start and end times must be different.").foregroundStyle(TransitTheme.error)
                    } else if endMinutes < startMinutes {
                        Text("This shift ends on the following day.").foregroundStyle(TransitTheme.secondaryText)
                    }
                    if let errorMessage { Text(errorMessage).foregroundStyle(TransitTheme.error) }
                }
                .listRowBackground(TransitTheme.surface)
                if shift != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmsDeletion = true
                        } label: {
                            Label("Delete Shift", systemImage: "trash")
                        }
                    } footer: {
                        Text("This removes only this employee's shift for the selected workday.")
                    }
                    .listRowBackground(TransitTheme.surface)
                }
            }
            .transitScreenStyle()
            .navigationTitle(shift == nil ? "Add Shift" : "Edit Shift")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete Shift?",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete Shift", role: .destructive, action: deleteShift)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently removes \(employee.name)'s shift for \(workday.formatted(date: .abbreviated, time: .omitted)).")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(startMinutes == endMinutes)
                }
            }
        }
        .environment(\.calendar, WorkdayDate.localCalendar)
    }

    private func clockMinutes(_ date: Date) -> Int {
        let parts = WorkdayDate.localCalendar.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }

    // A clock time in the spring-forward gap cannot be saved on that workday.
    private func combine(day: Date, minutes: Int, calendar: Calendar) -> Date? {
        guard let date = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: day),
              calendar.isDate(date, inSameDayAs: day),
              clockMinutes(date) == minutes else { return nil }
        return date
    }

    private func save() {
        guard startMinutes != endMinutes else {
            errorMessage = "Start and end times must be different."
            return
        }
        let calendar = WorkdayDate.localCalendar
        let day = calendar.startOfDay(for: workday)
        guard let endDay = endMinutes < startMinutes ? calendar.date(byAdding: .day, value: 1, to: day) : day,
              let start = combine(day: day, minutes: startMinutes, calendar: calendar),
              let end = combine(day: endDay, minutes: endMinutes, calendar: calendar),
              end > start else {
            errorMessage = "These times are unavailable on this workday. Choose different times."
            return
        }
        do {
            let savedShifts = try modelContext.fetch(FetchDescriptor<Shift>())
            guard !savedShifts.contains(where: {
                $0.id != shift?.id && $0.employee?.id == employee.id &&
                WorkdayDate.matches($0.workday, localDate: day, calendar: calendar)
            }) else {
                errorMessage = "This employee already has a shift on that workday. Edit the existing shift or choose another date."
                return
            }
        } catch {
            errorMessage = "Could not check this workday's shifts. Please try again."
            return
        }

        let storedWorkday = WorkdayDate.storedDate(fromLocal: day, calendar: calendar)
        let savedShift = shift ?? Shift(workday: storedWorkday, startsAt: start, endsAt: end, employee: employee)
        let original = (savedShift.workday, savedShift.startsAt, savedShift.endsAt, savedShift.employee)
        if shift == nil { modelContext.insert(savedShift) }
        savedShift.workday = storedWorkday
        savedShift.startsAt = start
        savedShift.endsAt = end
        savedShift.employee = employee
        do {
            try modelContext.save()
            Task { await activityCoordinator.scheduleOrUpdate(shift: savedShift) }
            onSaved()
            dismiss()
        } catch {
            if shift == nil {
                modelContext.delete(savedShift)
            } else {
                savedShift.workday = original.0
                savedShift.startsAt = original.1
                savedShift.endsAt = original.2
                savedShift.employee = original.3
            }
            errorMessage = "Could not save this shift. Please try again."
        }
    }

    private func deleteShift() {
        guard let shift else { return }
        modelContext.delete(shift)
        do {
            try modelContext.save()
            Task { await activityCoordinator.endActivities(forShiftIDs: [shift.id]) }
            onSaved()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "Could not delete this shift. Please try again."
        }
    }
}
