import AppKit
import ApplicationServices
import CoreGraphics

/// Checks privacy permissions without prompting, and opens the right Settings pane when asked.
/// macOS ties grants to the app's code signature, so these stay granted across updates only when
/// Shotty is signed with a stable certificate (see scripts/setup-signing.sh, spec 0006).
@MainActor
enum Permissions {
    enum Kind { case accessibility, screenRecording }

    /// Silent checks: never show a system dialog.
    static var accessibility: Bool { AXIsProcessTrusted() }
    static var screenRecording: Bool { CGPreflightScreenCaptureAccess() }

    private static var askedThisLaunch: Set<String> = []

    /// Shows the system prompt at most once per launch, then only opens System Settings.
    static func request(_ kind: Kind) {
        let key = "\(kind)"
        if askedThisLaunch.contains(key) {
            openSettings(kind)
            return
        }
        askedThisLaunch.insert(key)
        switch kind {
        case .accessibility:
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        case .screenRecording:
            _ = CGRequestScreenCaptureAccess()
        }
    }

    static func openSettings(_ kind: Kind) {
        let anchor = kind == .accessibility ? "Privacy_Accessibility" : "Privacy_ScreenCapture"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") {
            NSWorkspace.shared.open(url)
        }
    }

    /// True when the running copy is ad-hoc signed, so macOS will forget grants after a rebuild.
    static var isAdHocSigned: Bool {
        var code: SecStaticCode?
        guard SecStaticCodeCreateWithPath(Bundle.main.bundleURL as CFURL, [], &code) == errSecSuccess, let code else { return true }
        var info: CFDictionary?
        guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &info) == errSecSuccess,
              let dict = info as? [String: Any] else { return true }
        let certs = dict[kSecCodeInfoCertificates as String] as? [SecCertificate] ?? []
        return certs.isEmpty
    }
}
