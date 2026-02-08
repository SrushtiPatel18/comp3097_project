import SwiftUI
import SwiftData

struct EditTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var categories: [SPCategory]

    @Bindable var transaction: SPTransaction

    @State private var amountText: String = ""
    @State private var noteText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {

                    TextField("Title", text: $transaction.title)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Toggle("Income", isOn: $transaction.isIncome)

                    Picker("Category", selection: $transaction.categoryName) {
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    DatePicker(
                        "Date",
                        selection: $transaction.date,
                        displayedComponents: .date
                    )

                    TextField("Note (optional)", text: $noteText)
                }
            }
            .navigationTitle("Edit Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                amountText = String(transaction.amount)
                noteText = transaction.note ?? ""
            }
        }
    }

    private var categoryNames: [String] {
        let list = categories.map { $0.name }.sorted()
        return list.isEmpty
            ? ["Food", "Travel", "Entertainment", "Utilities"]
            : list
    }

    private func saveChanges() {
        if let value = Double(amountText) {
            transaction.amount = value
        }

        transaction.note = noteText.isEmpty ? nil : noteText
        dismiss()
    }
}
