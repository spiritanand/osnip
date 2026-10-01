import AppKit
import CoreGraphics

public enum ScreenRecordingPermission {
    static let settingsPane = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")

    public static func isGranted() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    public static func requestAndOpenSettings() {
        _ = CGRequestScreenCaptureAccess()
        if let settingsPane { NSWorkspace.shared.open(settingsPane) }
    }
}
