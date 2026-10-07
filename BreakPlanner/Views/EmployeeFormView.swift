import SwiftUI
import SwiftData

struct EmployeeFormView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    private let employee: Employee?
    private let onSaved: () -> Void
    @State private var name: String
    @State private var errorMessage: String?

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
                if let errorMessage {
                    Section { Text(errorMessage).foregroundStyle(TransitTheme.error) }
                        .listRowBackground(TransitTheme.surface)
                }
            }
            .transitScreenStyle()
            .navigationTitle(employee == nil ? "Add Employee" : "Edit Employee")
            .navigationBarTitleDisplayMode(.inline)
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
}
