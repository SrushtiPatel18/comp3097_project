import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var ctx

    @Query(sort: \SPTransaction.date, order: .reverse)
    private var txs: [SPTransaction]

    @Query private var settings: [SPSettings]

    @State private var showAdd = false
    @State private var showAll = false

    private var budget: Double { settings.first?.monthlyBudget ?? 2000 }

    private var spent: Double {
        txs.filter { !$0.isIncome }.reduce(0) { $0 + $1.amount }
    }

    private var remaining: Double {
        max(budget - spent, 0)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {

                    // Budget Card
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome, Samantha!")
                            .font(AppTheme.headline)

                        Text("Monthly Budget")
                            .font(AppTheme.caption)
                            .foregroundStyle(.secondary)

                        HStack {
                            Text(spent, format: .currency(code: "CAD"))
                                .font(.system(size: 22, weight: .bold, design: .rounded))

                            Text("/ \(budget, format: .currency(code: "CAD"))")
                                .font(AppTheme.body)
                                .foregroundStyle(.secondary)

                            Spacer()
                        }

                        ProgressView(value: min(spent / max(budget, 1), 1))
                            .tint(AppTheme.purple)

                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .foregroundStyle(AppTheme.blue)
                            Text("You have \(remaining, format: .currency(code: "CAD")) remaining")
                                .font(AppTheme.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .spCard()

                    // Recent Transactions Card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Recent Transactions")
                                .font(AppTheme.headline)

                            Spacer()

                            Button("See All") { showAll = true }
                                .font(AppTheme.caption)
                                .foregroundStyle(AppTheme.blue)
                        }

                        if txs.isEmpty {
                            Text("No transactions yet. Tap + to add one.")
                                .font(AppTheme.body)
                                .foregroundStyle(.secondary)
                                .padding(.top, 4)
                        } else {
                            ForEach(txs.prefix(4)) { t in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(t.title)
                                            .font(AppTheme.body)
                                            .fontWeight(.semibold)

                                        Text(t.categoryName)
                                            .font(AppTheme.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Text((t.isIncome ? t.amount : -t.amount),
                                         format: .currency(code: "CAD"))
                                    .font(AppTheme.body)
                                    .foregroundStyle(t.isIncome ? AppTheme.good : AppTheme.bad)
                                }

                                Divider().opacity(0.5)
                            }
                        }
                    }
                    .spCard()

                }
                .padding()
            }
            .background(AppTheme.bgGradient.ignoresSafeArea())
            .navigationTitle("SmartPocket")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showAdd = true } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(AppTheme.purple)
                    }
                }
            }
            .sheet(isPresented: $showAdd, content: { AddTransactionView() })
            .sheet(isPresented: $showAll, content: { TransactionsListView() })
            .onAppear { seedIfNeeded() }
        }
    }

    private func seedIfNeeded() {
        if settings.isEmpty {
            ctx.insert(SPSettings(monthlyBudget: 2000))
        }
    }
}
