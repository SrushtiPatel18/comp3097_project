import SwiftUI
import SwiftData

struct AddTransactionView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var ctx

    @Query private var categories: [SPCategory]

    @State private var title = ""
    @State private var amountText = ""
    @State private var isIncome = false
    @State private var selectedCategory = "Food"
    @State private var date = Date()
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Transaction") {
                    TextField("Title", text: $title)
                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Toggle("Income", isOn: $isIncome)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)
                    TextField("Note (optional)", text: $note)
                }
            }
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear { seedCategoriesIfNeeded() }
        }
    }

    private var categoryNames: [String] {
        let list = categories.map { $0.name }.sorted()
        return list.isEmpty ? ["Food","Travel","Entertainment","Utilities"] : list
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && Double(amountText) != nil
    }

    private func save() {
        guard let amount = Double(amountText) else { return }
        ctx.insert(SPTransaction(
            title: title,
            amount: amount,
            isIncome: isIncome,
            categoryName: selectedCategory,
            date: date,
            note: note.isEmpty ? nil : note
        ))
        dismiss()
    }

    private func seedCategoriesIfNeeded() {
        if categories.isEmpty {
            ["Food","Travel","Entertainment","Utilities"].forEach { ctx.insert(SPCategory(name: $0)) }
        }
    }
}
