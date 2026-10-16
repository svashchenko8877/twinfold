import SwiftUI

@main
struct TwinfoldApp: App {
    @StateObject private var store = GameStore()
    @StateObject private var purchases = PurchaseManager()
    var body: some Scene {
        WindowGroup {
            HomeView().environmentObject(store).environmentObject(purchases).preferredColorScheme(.dark)
        }
    }
}
