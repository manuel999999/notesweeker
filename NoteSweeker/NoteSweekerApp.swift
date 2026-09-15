import SwiftUI

@main
struct NoteSweekerApp: App {
    @StateObject private var store = NoteStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .windowResizability(.contentSize)
    }
}
