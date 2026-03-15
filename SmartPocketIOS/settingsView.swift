import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var ctx

    @Query private var settings: [SPSettings]
    @Query(sort: \SPCategory.name) private var categories: [SPCategory]

    @State private var budgetText = ""
    @State private var newCategory = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Budget Management")
                            .font(AppTheme.headline)

                        TextField("Monthly Budget", text: $budgetText)
                            .keyboardType(.decimalPad)
                            .padding(12)
                            .background(Color.white.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        Button {
                            saveBudget()
                        } label: {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Save Budget")
                            }
                            .font(AppTheme.body)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [AppTheme.purple, AppTheme.blue],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .spCard()

                    // Category Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Category Management")
                            .font(AppTheme.headline)

                        if categories.isEmpty {
                            Text("No categories yet.")
                                .font(AppTheme.body)
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(categories) { cat in
                                HStack {
                                    Text(cat.name)
                                        .font(AppTheme.body)

                                    Spacer()

                                    Button(role: .destructive) {
                                        ctx.delete(cat)
                                    } label: {
                                        Image(systemName: "trash")
                                    }
                                }
                                Divider().opacity(0.4)
                            }
                        }

                        HStack {
                            TextField("New Category", text: $newCategory)
                                .padding(12)
                                .background(Color.white.opacity(0.6))
                                .clipShape(RoundedRectangle(cornerRadius: 12))

                            Button("Add") { addCategory() }
                                .font(AppTheme.body)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(AppTheme.blue)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .spCard()

                    // Reset Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Danger Zone")
                            .font(AppTheme.headline)

                        Button(role: .destructive) {
                            resetAllData()
                        } label: {
                            HStack {
                                Image(systemName: "trash.fill")
                                Text("Reset All Data")
                            }
                            .font(AppTheme.body)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                    }
                    .spCard()
                }
                .padding()
            }
            .background(AppTheme.bgGradient.ignoresSafeArea())
            .navigationTitle("Settings")
            .onAppear {
                seedIfNeeded()
                budgetText = String(settings.first?.monthlyBudget ?? 2000)
            }
        }
    }

    // MARK: - Logic
    private func seedIfNeeded() {
        if settings.isEmpty {
            ctx.insert(SPSettings(monthlyBudget: 2000))
        }
        if categories.isEmpty {
            ["Food", "Travel", "Entertainment", "Utilities"].forEach {
                ctx.insert(SPCategory(name: $0))
            }
        }
    }

    private func saveBudget() {
        guard let value = Double(budgetText) else { return }
        if let s = settings.first {
            s.monthlyBudget = value
        } else {
            ctx.insert(SPSettings(monthlyBudget: value))
        }
    }

    private func addCategory() {
        let name = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        if !categories.contains(where: { $0.name.lowercased() == name.lowercased() }) {
            ctx.insert(SPCategory(name: name))
        }
        newCategory = ""
    }

    private func resetAllData() {
        if let txList = try? ctx.fetch(FetchDescriptor<SPTransaction>()) {
            txList.forEach { ctx.delete($0) }
        }
        if let catList = try? ctx.fetch(FetchDescriptor<SPCategory>()) {
            catList.forEach { ctx.delete($0) }
        }

        if let s = settings.first {
            s.monthlyBudget = 2000
        } else {
            ctx.insert(SPSettings(monthlyBudget: 2000))
        }

        ["Food", "Travel", "Entertainment", "Utilities"].forEach {
            ctx.insert(SPCategory(name: $0))
        }
    }
}
