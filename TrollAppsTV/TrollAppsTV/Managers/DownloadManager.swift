// Based on TrollAppsTV by TheResonanceTeam. Distributed under GPL-3.0.
import SwiftUI

struct TransferAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

// Published state is only modified on the main queue.
final class DownloadState: ObservableObject {
    static let shared = DownloadState()
    @Published var isBusy = false
    @Published var status = ""
    @Published var progress: Double?
    @Published var alert: TransferAlert?

    func finish(error: String? = nil) {
        DispatchQueue.main.async {
            self.isBusy = false
            self.progress = nil
            self.status = ""
            self.alert = TransferAlert(title: error == nil ? "Installed" : "Installation failed",
                                      message: error ?? "The app was installed successfully.")
        }
    }
}

final class DownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let isTrollAppsUpdate: Bool
    private var handledDownload = false

    init(isTrollAppsUpdate: Bool) { self.isTrollAppsUpdate = isTrollAppsUpdate }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        handledDownload = true
        defer { session.finishTasksAndInvalidate() }
        guard let response = downloadTask.response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
            let code = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 0
            DownloadState.shared.finish(error: "The server returned HTTP \(code). Check the app's direct download URL.")
            return
        }
        let folder = URL(fileURLWithPath: "/private/var/mobile/.TrollApps/tmp", isDirectory: true)
        let ipa = folder.appendingPathComponent(UUID().uuidString).appendingPathExtension("ipa")
        defer {
            do {
                if FileManager.default.fileExists(atPath: ipa.path) { try FileManager.default.removeItem(at: ipa) }
            } catch { print("Could not remove temporary IPA: \(error)") }
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true, attributes: nil)
            try FileManager.default.moveItem(at: location, to: ipa)
            DispatchQueue.main.async {
                DownloadState.shared.status = "Installing…"
                DownloadState.shared.progress = nil
            }
            try InstallIPA(at: ipa, isTrollAppsUpdate: isTrollAppsUpdate)
            DownloadState.shared.finish()
        } catch {
            print("Download/install failed: \(error)")
            DownloadState.shared.finish(error: error.localizedDescription)
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        DispatchQueue.main.async {
            DownloadState.shared.progress = totalBytesExpectedToWrite > 0
                ? min(1, Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)) : nil
            DownloadState.shared.status = "Downloading… \(ByteCountFormatter.string(fromByteCount: totalBytesWritten, countStyle: .file))"
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard !handledDownload else { return }
        session.finishTasksAndInvalidate()
        DownloadState.shared.finish(error: error?.localizedDescription ?? "The download ended without a file.")
    }
}

func downloadIPA(_ appUrl: String, isTrollAppsUpdate: Bool) {
    let state = DownloadState.shared
    guard !state.isBusy else { return }
    guard let url = URL(string: appUrl), let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme), url.host != nil else {
        state.finish(error: "The repository contains an invalid download URL.")
        return
    }
    state.alert = nil
    state.isBusy = true
    state.status = "Starting download…"
    state.progress = nil
    let configuration = URLSessionConfiguration.default
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 1800
    let delegate = DownloadDelegate(isTrollAppsUpdate: isTrollAppsUpdate)
    let session = URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    session.downloadTask(with: url).resume()
}
