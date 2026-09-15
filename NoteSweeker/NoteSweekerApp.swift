import SwiftUI

@main
struct NoteSweekerApp: App {
    var body: some Scene {
        WindowGroup {
            WelcomeView()
        }
        .windowResizability(.contentSize)
    }
}
