import SwiftUI

struct ContentView: View {
    var body: some View {
        // LoginView is the root screen on launch.
        // The onSignIn closure is a no-op stub; real authentication
        // will be wired in a subsequent PR.
        LoginView(onSignIn: { _, _, _ in })
    }
}

#Preview {
    ContentView()
}
