// Based on TrollAppsTV by TheResonanceTeam. Distributed under GPL-3.0.
import SwiftUI

struct ContentView: View {
    @ObservedObject private var transfer = DownloadState.shared

    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                SourcesView().tabItem { Label("Sources", systemImage: "globe") }
                SearchView().tabItem { Label("Search", systemImage: "magnifyingglass") }
                SettingsView().tabItem { Label("Settings", systemImage: "gearshape.fill") }
            }
            if transfer.isBusy {
                VStack(spacing: 12) {
                    Text(transfer.status)
                    if let progress = transfer.progress {
                        ProgressView(value: progress)
                    } else {
                        ProgressView()
                    }
                }
                .padding(24)
                .frame(maxWidth: 640)
                .background(Color.black.opacity(0.9))
                .cornerRadius(16)
                .padding(.bottom, 40)
            }
        }
        .alert(item: $transfer.alert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message), dismissButton: .default(Text("OK")))
        }
    }
}
