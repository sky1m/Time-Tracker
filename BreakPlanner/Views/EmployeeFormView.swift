import SwiftUI
import SwiftData

struct EmployeeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var activityCoordinator: BreakActivityCoordinator
    private let employee: Employee?
    private let onSaved: () -> Void
    @State private var name: String
    @State private var errorMessage: String?
    @State private var confirmsDeletion = false

    init(employee: Employee?, onSaved: @escaping () -> Void) {
        self.employee = employee
        self.onSaved = onSaved
        _name = State(initialValue: employee?.name ?? "")
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Employee") {
                    TextField("Name", text: $name)
                        .textContentType(.name)
                    if trimmedName.isEmpty {
                        Text("Enter an employee name.").foregroundStyle(TransitTheme.secondaryText)
                    }
                }
                .listRowBackground(TransitTheme.surface)
                if employee != nil {
                    Section {
                        Button(role: .destructive) {
                            confirmsDeletion = true
                        } label: {
                            Label("Delete Employee", systemImage: "trash")
                        }
                    } footer: {
                        Text("Deleting this employee also deletes all of their saved shifts.")
                    }
                    .listRowBackground(TransitTheme.surface)
                }
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(TransitTheme.error) }
                        .listRowBackground(TransitTheme.surface)
                }
            }
            .transitScreenStyle()
            .navigationTitle(employee == nil ? "Add Employee" : "Edit Employee")
            .navigationBarTitleDisplayMode(.inline)
            .confirmationDialog(
                "Delete Employee?",
                isPresented: $confirmsDeletion,
                titleVisibility: .visible
            ) {
                Button("Delete Employee and Shifts", role: .destructive, action: deleteEmployee)
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This permanently removes \(employee?.name ?? "this employee") and all of their saved shifts.")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save).disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private func save() {
        guard !trimmedName.isEmpty else {
            errorMessage = "Enter an employee name before saving."
            return
        }
        let savedEmployee = employee ?? Employee(name: trimmedName)
        let originalName = savedEmployee.name
        if employee == nil { modelContext.insert(savedEmployee) }
        savedEmployee.name = trimmedName
        do {
            try modelContext.save()
            onSaved()
            dismiss()
        } catch {
            if employee == nil {
                modelContext.delete(savedEmployee)
            } else {
                savedEmployee.name = originalName
            }
            errorMessage = "Could not save this employee. Please try again."
        }
    }

    private func deleteEmployee() {
        guard let employee else { return }
        let savedShifts: [Shift]
        do {
            savedShifts = try modelContext.fetch(FetchDescriptor<Shift>())
                .filter { $0.employee?.id == employee.id }
        } catch {
            errorMessage = "Could not load this employee's shifts. Please try again."
            return
        }

        for shift in savedShifts {
            modelContext.delete(shift)
        }
        modelContext.delete(employee)
        do {
            try modelContext.save()
            let shiftIDs = savedShifts.map(\.id)
            Task { await activityCoordinator.endActivities(forShiftIDs: shiftIDs) }
            onSaved()
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = "Could not delete this employee. Please try again."
        }
    }
}
