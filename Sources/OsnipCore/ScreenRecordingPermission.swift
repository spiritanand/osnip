import AppKit
import CoreGraphics

enum ScreenRecordingPermission {
    static let settingsPane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    static func isGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestAndOpenSettings() {
        _ = CGRequestScreenCaptureAccess()
        if let settingsPane { NSWorkspace.shared.open(settingsPane) }
    }
}
