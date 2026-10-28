// Based on TrollAppsTV by TheResonanceTeam. Distributed under GPL-3.0.
import Foundation

enum IPAInstallError: LocalizedError {
    case fileMissing
    case helperMissing
    case helperFailed(Int32)

    var errorDescription: String? {
        switch self {
        case .fileMissing:
            return "The downloaded IPA could not be found. Please download it again."
        case .helperMissing:
            return "No TrollStore or TrollStore Lite helper was found. Checked /Applications, /var/jb/Applications and app containers."
        case .helperFailed(let code):
            return "TrollStore's installer returned code \(code). Check that TrollAppsTV is installed through TrollStore Lite with its original entitlements and that your jailbreak is active."
        }
    }
}

// Return the app directory, checking the helper itself rather than a directory
// that might be a stale installation. Injectable roots allow local verification.
func findTrollStoreApp(fileManager: FileManager = .default,
                       applicationRoots: [String] = ["/Applications", "/var/jb/Applications"],
                       containerRoots: [String] = ["/private/var/containers/Bundle/Application"]) -> String? {
    let appNames = ["TrollStoreLite.app", "TrollStore.app"]
    func usableApp(in root: String) -> String? {
        for name in appNames {
            let app = URL(fileURLWithPath: root).appendingPathComponent(name)
            let helper = app.appendingPathComponent("trollstorehelper").path
            if fileManager.isExecutableFile(atPath: helper) { return app.path }
        }
        return nil
    }
    for root in applicationRoots {
        if let app = usableApp(in: root) { return app }
    }
    for root in containerRoots {
        guard let directories = try? fileManager.contentsOfDirectory(atPath: root) else { continue }
        for directory in directories.sorted() {
            if let app = usableApp(in: URL(fileURLWithPath: root).appendingPathComponent(directory).path) { return app }
        }
    }
    return nil
}

func runIPAInstall(at ipaURL: URL, helperPath: String,
                   runHelper: (String, [String]) -> Int32 = { spawnRoot($0, $1) }) throws {
    guard FileManager.default.fileExists(atPath: ipaURL.path) else { throw IPAInstallError.fileMissing }
    let code = runHelper(helperPath, ["install", ipaURL.path])
    guard code == 0 else { throw IPAInstallError.helperFailed(code) }
}

func InstallIPA(at ipaURL: URL, isTrollAppsUpdate: Bool) throws {
    guard let app = findTrollStoreApp() else { throw IPAInstallError.helperMissing }
    let helper = URL(fileURLWithPath: app).appendingPathComponent("trollstorehelper").path
    print("Installing IPA with \(helper)")
    try runIPAInstall(at: ipaURL, helperPath: helper)
    DispatchQueue.main.async {
        NotificationCenter.default.post(name: Notification.Name("ApplicationsChanged"), object: nil)
        if isTrollAppsUpdate { closeTrollApps() }
    }
}

func DeleteIPA(_ itemID: UUID) -> Bool {
    let url = URL(fileURLWithPath: "/private/var/mobile/.TrollApps/tmp", isDirectory: true)
        .appendingPathComponent(itemID.uuidString).appendingPathExtension("ipa")
    do {
        if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
        return true
    } catch { return false }
}
