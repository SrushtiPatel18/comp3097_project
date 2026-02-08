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

    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Quick Add")
                            .font(AppTheme.headline)
                        Text("Add an income or expense in a few seconds.")
                            .font(AppTheme.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
                .listRowBackground(Color.clear)

                Section("Details") {
                    TextField("Title (e.g., Groceries)", text: $title)

                    TextField("Amount", text: $amountText)
                        .keyboardType(.decimalPad)

                    Toggle(isIncome ? "Income" : "Expense", isOn: $isIncome)
                        .tint(AppTheme.purple)

                    Picker("Category", selection: $selectedCategory) {
                        ForEach(categoryNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }

                    DatePicker("Date", selection: $date, displayedComponents: .date)

                    TextField("Note (optional)", text: $note)
                }

                Section {
                    Button {
                        if validate() {
                            save()
                        } else {
                            showError = true
                        }
                    } label: {
                        HStack {
                            Spacer()
                            Text("Save Transaction")
                                .font(AppTheme.body)
                                .fontWeight(.semibold)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                    .listRowBackground(
                        LinearGradient(colors: [AppTheme.purple, AppTheme.blue],
                                       startPoint: .leading, endPoint: .trailing)
                            .opacity(canSave ? 1 : 0.45)
                    )
                    .foregroundStyle(.white)
                    .disabled(!canSave)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AppTheme.bgGradient)
            .navigationTitle("Add Transaction")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(AppTheme.blue)
                }
            }
            .alert("Please fill required fields", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Enter a title and a valid amount.")
            }
            .onAppear {
                seedCategoriesIfNeeded()
                if !categoryNames.contains(selectedCategory) {
                    selectedCategory = categoryNames.first ?? "Food"
                }
            }
        }
    }

    private var categoryNames: [String] {
        let list = categories.map { $0.name }.sorted()
        return list.isEmpty ? ["Food","Travel","Entertainment","Utilities"] : list
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        Double(amountText) != nil
    }

    private func validate() -> Bool { canSave }

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
