import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Environment(\.modelContext) private var ctx

    @Query(sort: \SPTransaction.date, order: .reverse)
    private var txs: [SPTransaction]

    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var editItem: SPTransaction? = nil

    enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case expenses = "Expenses"
        case income = "Income"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                // Filter bar
                Picker("Filter", selection: $filter) {
                    ForEach(Filter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .tint(AppTheme.purple)

                List {
                    ForEach(filtered) { t in
                        TransactionRow(t: t)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                editItem = t
                            }
                    }
                    .onDelete(perform: delete)
                }
                .scrollContentBackground(.hidden)
                .background(AppTheme.bgGradient)
            }
            .navigationTitle("Transactions")
            .searchable(text: $search, prompt: "Search title or category")
            .background(AppTheme.bgGradient.ignoresSafeArea())
            .sheet(item: $editItem) { item in
                EditTransactionView(transaction: item)
            }
        }
    }

    private var filtered: [SPTransaction] {
        // 1) apply filter
        let base: [SPTransaction] = {
            switch filter {
            case .all: return txs
            case .expenses: return txs.filter { !$0.isIncome }
            case .income: return txs.filter { $0.isIncome }
            }
        }()

        // 2) apply search to it
        let q = search.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return base }

        return base.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.categoryName.localizedCaseInsensitiveContains(q)
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            let item = filtered[index]
            ctx.delete(item)
        }
    }
}
