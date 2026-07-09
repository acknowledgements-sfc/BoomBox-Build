import SwiftUI

struct ContentView: View {
    var body: some View {
        #if DEBUG
        NavigationStack {
            VStack(spacing: 16) {
                Text("ParkJukebox")
                    .font(.title)
                NavigationLink("Learning Tests (P1-1)") {
                    LearningTestsMenuView()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .navigationTitle("ParkJukebox")
        }
        #else
        Text("ParkJukebox")
            .font(.title)
            .padding()
        #endif
    }
}

#Preview {
    ContentView()
}
