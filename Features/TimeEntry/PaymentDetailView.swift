import SwiftUI

struct PaymentDetailView: View {
    @EnvironmentObject private var projectVM: ProjectViewModel
    @Environment(\.dismiss) private var dismiss

    /// All unpaid entries for a single employee
    let entries: [WorkHour]

    /// Available payment methods
    private let paymentMethods = ["Check", "Cash", "Bank Transfer"]

    @State private var selectedIDs = Set<UUID>()
    @State private var selectedMethod = "Check"    // default to first
    @State private var paymentNote = ""

    /// Computes the total of just the selected entries
    private var totalSelectedAmount: Double {
        entries
            .filter { selectedIDs.contains($0.id) }
            .reduce(0) { $0 + $1.hours * $1.rate }
    }

    var body: some View {
        NavigationStack {
            Form {
                // MARK: — Selectable List of Entries
                Section("Days to Pay") {
                    if entries.isEmpty {
                        Text("No unpaid entries available.")
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(entries) { entry in
                            HStack {
                                Button {
                                    toggleSelection(for: entry.id)
                                } label: {
                                    Image(systemName: selectedIDs.contains(entry.id)
                                          ? "checkmark.circle.fill"
                                          : "circle")
                                        .font(.title2)
                                        .foregroundColor(
                                            selectedIDs.contains(entry.id)
                                                ? .blue
                                                : .secondary
                                        )
                                }
                                .buttonStyle(.plain)

                                VStack(alignment: .leading, spacing: 2) {
                                    HStack {
                                        Text(entry.startTime, style: .date)
                                        Text(entry.startTime, style: .time)
                                        Text("–")
                                        if let end = entry.endTime {
                                            Text(end, style: .time)
                                        } else {
                                            Text("—")
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .font(.subheadline)

                                    Text(String(
                                        format: "Total: %.2fh @ $%.0f = $%.2f",
                                        entry.hours, entry.rate, entry.hours * entry.rate
                                    ))
                                    .font(.caption)
                                }

                                Spacer()

                                Text(String(format: "$%.2f", entry.hours * entry.rate))
                                    .bold()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // MARK: — Payment Method Segmented Control
                Section("Payment Method") {
                    Picker("", selection: $selectedMethod) {
                        ForEach(paymentMethods, id: \.self) { method in
                            Text(method).tag(method)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // MARK: — Payment Note
                Section("Note (optional)") {
                    TextField("Enter note", text: $paymentNote)
                }

                // MARK: — Total Selected
                if !selectedIDs.isEmpty {
                    Section {
                        HStack {
                            Text("Total for Selected")
                                .bold()
                            Spacer()
                            Text(String(format: "$%.2f", totalSelectedAmount))
                                .bold()
                        }
                    }
                }

                // MARK: — Finalize Button
                Section {
                    HStack {
                        Spacer()
                        Button("Mark Selected as Paid") {
                            for entry in entries where selectedIDs.contains(entry.id) {
                                projectVM.markHoursAsPaid(
                                    entry,
                                    method: selectedMethod,
                                    note: paymentNote
                                )
                            }
                            dismiss()
                        }
                        // Enabled only when at least one entry is selected
                        .disabled(selectedIDs.isEmpty)
                        Spacer()
                    }
                }
            }
            .navigationTitle("Process Payment")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func toggleSelection(for id: UUID) {
        if selectedIDs.contains(id) {
            selectedIDs.remove(id)
        } else {
            selectedIDs.insert(id)
        }
    }
}
