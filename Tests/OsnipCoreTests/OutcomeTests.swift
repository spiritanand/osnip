import Testing
@testable import OsnipCore

@Test(arguments: [
    (Outcome.copied(originalBytes: 425_000, optimizedBytes: 68_000), "Copied · 425 KB → 68 KB (−84%)"),
    (Outcome.copied(originalBytes: 1_400_000, optimizedBytes: 143_000), "Copied · 1.4 MB → 143 KB (−90%)"),
    (Outcome.copied(originalBytes: 100_000, optimizedBytes: 99_000), "Copied · 100 KB → 99 KB (−1%)"),
    (Outcome.copied(originalBytes: 100_000, optimizedBytes: 99_250), "Copied · 99 KB"),
    (Outcome.copied(originalBytes: 3_000, optimizedBytes: 2_990), "Copied · 3 KB"),
    (Outcome.copied(originalBytes: 3_000, optimizedBytes: 3_600), "Copied · 4 KB"),
    (Outcome.copied(originalBytes: 0, optimizedBytes: 10), "Copied · 1 KB"),
    (Outcome.copiedOriginal, "Copied original · Optimization failed"),
    (Outcome.screenRecordingDenied, "Allow Screen Recording for Raycast"),
    (Outcome.captureFailed, "Couldn't capture"),
    (Outcome.clipboardFailed, "Couldn't copy"),
])
func printsTheApprovedLine(outcome: Outcome, line: String) {
    #expect(outcome.hudLine == line)
}

@Test(arguments: [Outcome.cancelled, Outcome.busy])
func staysSilent(outcome: Outcome) {
    #expect(outcome.hudLine == nil)
}

@Test(arguments: [
    (Outcome.copied(originalBytes: 2, optimizedBytes: 1), Int32(0)), (Outcome.copiedOriginal, 0), (Outcome.cancelled, 0),
    (Outcome.busy, 0), (Outcome.screenRecordingDenied, 1), (Outcome.captureFailed, 1), (Outcome.clipboardFailed, 1),
] as [(Outcome, Int32)])
func exitsWithTheDocumentedCode(outcome: Outcome, code: Int32) {
    #expect(outcome.exitCode == code)
}
