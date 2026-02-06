import SwiftUI
import SwiftData

struct TransactionsListView: View {
    @Query(sort: \SPTransaction.date, order: .reverse)
    private var txs: [SPTransaction]

    @State private var search = ""

    var body: some View {
        NavigationStack {
            List(filtered) { t in
                HStack {
                    VStack(alignment: .leading) {
                        Text(t.title).font(.headline)
                        Text(t.categoryName).font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text((t.isIncome ? t.amount : -t.amount), format: .currency(code: "CAD"))
                        .foregroundStyle(t.isIncome ? .green : .red)
                }
            }
            .navigationTitle("All Transactions")
            .searchable(text: $search)
        }
    }

    private var filtered: [SPTransaction] {
        let q = search.trimmingCharacters(in: .whitespaces)
        if q.isEmpty { return txs }
        return txs.filter {
            $0.title.localizedCaseInsensitiveContains(q) ||
            $0.categoryName.localizedCaseInsensitiveContains(q)
        }
    }
}
