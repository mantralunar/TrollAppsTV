import Foundation

// The local tests never execute a real installer or request root access.
func spawnRoot(_ path: String, _ arguments: [String]) -> Int32 { fatalError("Unexpected real helper call") }
func closeTrollApps() {}

@main
struct InstallerTests {
    static func main() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }
        let applications = root.appendingPathComponent("Applications")
        let rootless = root.appendingPathComponent("var/jb/Applications")
        let containers = root.appendingPathComponent("containers")
        for url in [applications, rootless, containers] {
            try fm.createDirectory(at: url, withIntermediateDirectories: true)
        }
        func createHelper(_ app: URL, executable: Bool = true) throws -> String {
            try fm.createDirectory(at: app, withIntermediateDirectories: true)
            let helper = app.appendingPathComponent("trollstorehelper")
            try Data("test fixture".utf8).write(to: helper)
            try fm.setAttributes([.posixPermissions: executable ? 0o755 : 0o644], ofItemAtPath: helper.path)
            return helper.path
        }
        func discover() -> String? {
            findTrollStoreApp(applicationRoots: [applications.path, rootless.path], containerRoots: [containers.path])
        }
        precondition(discover() == nil)
        let containerApp = containers.appendingPathComponent("UUID/TrollStore.app")
        _ = try createHelper(containerApp)
        precondition(discover() == containerApp.path)
        let rootlessApp = rootless.appendingPathComponent("TrollStoreLite.app")
        _ = try createHelper(rootlessApp)
        precondition(discover() == rootlessApp.path)
        let liteApp = applications.appendingPathComponent("TrollStoreLite.app")
        let helper = try createHelper(liteApp, executable: false)
        precondition(discover() == rootlessApp.path)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: helper)
        precondition(discover() == liteApp.path)
        let ipa = root.appendingPathComponent("test.ipa")
        try Data("IPA fixture".utf8).write(to: ipa)
        var invoked = false
        try runIPAInstall(at: ipa, helperPath: helper) { path, args in
            precondition(path == helper && args == ["install", ipa.path])
            invoked = true
            return 0
        }
        precondition(invoked)
        do {
            try runIPAInstall(at: ipa, helperPath: helper) { _, _ in 175 }
            fatalError("Non-zero installer result was ignored")
        } catch IPAInstallError.helperFailed(let code) { precondition(code == 175) }
        try fm.removeItem(at: ipa)
        do {
            try runIPAInstall(at: ipa, helperPath: helper) { _, _ in fatalError("Missing IPA must not be installed") }
            fatalError("Missing file was accepted")
        } catch IPAInstallError.fileMissing {}
        print("PASS: Lite/rootless/container discovery, executable checks, install arguments, missing files, and helper error reporting")
    }
}
