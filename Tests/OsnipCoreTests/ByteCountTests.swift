import Testing
@testable import OsnipCore

@Test(arguments: [
    (0, "1 KB"), (400, "1 KB"), (1_499, "1 KB"), (1_500, "2 KB"), (68_400, "68 KB"), (412_000, "412 KB"),
    (999_499, "999 KB"), (999_500, "1.0 MB"), (1_000_000, "1.0 MB"), (1_449_000, "1.4 MB"), (13_300_000, "13.3 MB"),
])
func formatsSizesInDecimalUnits(bytes: Int, expected: String) {
    #expect(ByteCount.formatted(bytes) == expected)
}
