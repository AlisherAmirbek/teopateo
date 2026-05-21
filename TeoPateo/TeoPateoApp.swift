import SwiftUI

@main
struct TeoPateoApp: App {
    @StateObject private var store = TeoPateoStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
