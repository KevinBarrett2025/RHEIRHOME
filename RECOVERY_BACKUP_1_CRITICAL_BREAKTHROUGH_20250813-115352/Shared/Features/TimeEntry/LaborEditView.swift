import SwiftUI

struct LaborEditView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var startTime: Date = Date()
    @State private var endTime: Date = Date()
    @State private var selectedEmployee: Employee?
    @State private var selectedRate: EmployeeRate?
    @State private var selectedCategory = "Labor"
    @State private var tookLunchBreak = false
    @State private var lunchDurationText = ""

    private let categories = ["Labor", "General Conditions", "Contingency"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Employee & Rate") {
                    Menu {
                        ForEach(projectVM.employees) { emp in
                            Button(emp.name) {
                                selectedEmployee = emp
                                selectedRate = emp.rates.first
                            }
                        }
                        Divider()
                        Button("Add New Employee") {
                            // ...
                        }
                    } label: {
                        HStack {
                            Text(selectedEmployee?.name ?? "Select Employee")
                                .foregroundColor(selectedEmployee == nil ? .gray : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                    }

                    if let emp = selectedEmployee {
                        Picker("Rate", selection: $selectedRate) {
                            ForEach(emp.rates) { r in
                                Text("\(r.taskType) — $\(r.rate, specifier: "%.0f")/h")
                                    .tag(Optional(r))
                            }
                            Button("Add New Rate…") {
                                // ...
                            }
                            .tag(nil as EmployeeRate?)
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Category") {
                    Picker("Budget Category", selection: $selectedCategory) {
                        ForEach(categories, id: \.self) { cat in
                            Text(cat).tag(cat)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Clock In / Clock Out") {
                    DatePicker("Clock In", selection: $startTime, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("Clock Out", selection: $endTime, displayedComponents: [.date, .hourAndMinute])
                }

                Section("Lunch Break") {
                    Toggle("Took Lunch Break?", isOn: $tookLunchBreak)
                    if tookLunchBreak {
                        TextField("Duration (hrs)", text: $lunchDurationText)
                            .keyboardType(.decimalPad)
                    }
                }

                Section {
                    Button("Log Hours") {
                        guard
                            let emp = selectedEmployee,
                            let rateEnt = selectedRate ?? selectedEmployee?.rates.first
                        else { return }

                        let lunchDur = tookLunchBreak ? (Double(lunchDurationText) ?? 0) : nil

                        // This now calls the single `logHours(...)` in ProjectViewModel+TimeEntry.swift
                        projectVM.logHours(
                            startTime: startTime,
                            endTime: endTime,
                            employee: emp.name,
                            rate: rateEnt.rate,
                            category: selectedCategory,
                            lunchBreakDuration: lunchDur
                        )
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(selectedEmployee == nil || endTime <= startTime)
                }
            }
            .navigationTitle("Edit Hours")
            .toolbar(content: {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Cancel") { dismiss() }
                }
            })
        }
    }
}
