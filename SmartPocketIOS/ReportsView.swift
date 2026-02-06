import SwiftUI
import SwiftData
import Charts

struct ReportsView: View {
    @Query(sort: \SPTransaction.date, order: .reverse)
    private var txs: [SPTransaction]

    @State private var mode: Mode = .byCategory
    @State private var selectedDate: Date = .now

    enum Mode: String, CaseIterable, Identifiable {
        case byCategory = "By Category"
        case calendar = "Calendar View"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .tint(AppTheme.purple)

                if mode == .byCategory {
                    byCategoryView
                } else {
                    calendarView
                }

                Spacer()
            }
            .navigationTitle("Spending Reports")
            .background(AppTheme.bgGradient.ignoresSafeArea())
        }
    }

    private var byCategoryView: some View {
        let data = totalsByCategory()

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Spending by Category")
                    .font(AppTheme.headline)

                if data.isEmpty {
                    Text("No expense transactions yet.")
                        .font(AppTheme.body)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                } else {
                    Chart(data, id: \.category) { item in
                        SectorMark(
                            angle: .value("Amount", item.total),
                            innerRadius: .ratio(0.62)
                        )
                        .foregroundStyle(by: .value("Category", item.category))
                    }
                    .frame(height: 260)

                    Divider().opacity(0.5)

                    ForEach(data, id: \.category) { item in
                        HStack {
                            Text(item.category)
                                .font(AppTheme.body)
                            Spacer()
                            Text(item.total, format: .currency(code: "CAD"))
                                .font(AppTheme.body)
                                .foregroundStyle(.secondary)
                        }
                        Divider().opacity(0.4)
                    }
                }
            }
            .spCard()
            .padding()
        }
    }

    private var calendarView: some View {
        let dayTx = txs.filter { Calendar.current.isDate($0.date, inSameDayAs: selectedDate) }

        return ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Calendar View")
                    .font(AppTheme.headline)

                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(AppTheme.blue)

                Text("Transactions on \(selectedDate.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTheme.body)
                    .foregroundStyle(.secondary)

                if dayTx.isEmpty {
                    Text("No transactions on this date.")
                        .font(AppTheme.body)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(dayTx) { t in
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
                        Divider().opacity(0.4)
                    }
                }
            }
            .spCard()
            .padding()
        }
    }

    private func totalsByCategory() -> [(category: String, total: Double)] {
        let expenses = txs.filter { !$0.isIncome }
        let grouped = Dictionary(grouping: expenses, by: { $0.categoryName })
        return grouped.map { (key, list) in
            (category: key, total: list.reduce(0) { $0 + $1.amount })
        }
        .sorted { $0.total > $1.total }
    }
}
