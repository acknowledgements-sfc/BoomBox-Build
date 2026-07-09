#if DEBUG
import SwiftUI

struct LearningTestsMenuView: View {
    var body: some View {
        List {
            Section {
                Text("Throwaway P1-1 harnesses. Run on real devices only.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Learning Tests") {
                NavigationLink("LT-A: Output Latency") {
                    LTA_OutputLatencyView()
                }
                NavigationLink("LT-B: MPC sendResource") {
                    LTB_TransferView()
                }
                NavigationLink("LT-C: play(at:) Accuracy") {
                    LTC_HostTimeView()
                }
            }
        }
        .navigationTitle("Learning Tests")
    }
}
#endif
