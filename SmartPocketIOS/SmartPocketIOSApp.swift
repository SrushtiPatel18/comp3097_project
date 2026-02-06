import SwiftUI
import SwiftData

@main
struct SmartPocketIOSApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [SPTransaction.self, SPCategory.self, SPSettings.self])
    }
}
