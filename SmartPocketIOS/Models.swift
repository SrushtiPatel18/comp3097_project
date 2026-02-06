import Foundation
import SwiftData

@Model
final class SPTransaction {
    var title: String
    var amount: Double
    var isIncome: Bool
    var categoryName: String
    var date: Date
    var note: String?

    init(title: String, amount: Double, isIncome: Bool, categoryName: String, date: Date = .now, note: String? = nil) {
        self.title = title
        self.amount = amount
        self.isIncome = isIncome
        self.categoryName = categoryName
        self.date = date
        self.note = note
    }
}

@Model
final class SPCategory {
    var name: String
    init(name: String) { self.name = name }
}

@Model
final class SPSettings {
    var monthlyBudget: Double
    init(monthlyBudget: Double = 2000) { self.monthlyBudget = monthlyBudget }
}
