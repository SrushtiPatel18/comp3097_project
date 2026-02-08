import SwiftUI

struct TransactionRow: View {
    let t: SPTransaction

    private var iconName: String {
        switch t.categoryName.lowercased() {
        case "food": return "fork.knife"
        case "travel": return "airplane"
        case "entertainment": return "gamecontroller"
        case "utilities": return "bolt.fill"
        case "shopping": return "bag.fill"
        default: return "tag.fill"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [AppTheme.purple, AppTheme.blue],
                                         startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 42, height: 42)
                Image(systemName: iconName)
                    .foregroundStyle(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(t.title)
                    .font(AppTheme.body)
                    .fontWeight(.semibold)

                Text("\(t.categoryName) • \(t.date.formatted(date: .abbreviated, time: .omitted))")
                    .font(AppTheme.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text((t.isIncome ? t.amount : -t.amount), format: .currency(code: "CAD"))
                .font(AppTheme.body)
                .foregroundStyle(t.isIncome ? AppTheme.good : AppTheme.bad)
        }
        .padding(.vertical, 6)
    }
}
