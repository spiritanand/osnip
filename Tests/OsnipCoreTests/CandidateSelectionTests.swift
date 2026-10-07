import Testing
@testable import OsnipCore

@Test(arguments: [
    ([150, 90, 80, 70] as [Int?], 1),
    ([100, 50, 40, 30] as [Int?], 0),
    ([nil, 90, 80, 70] as [Int?], 1),
    ([300, 200, 200, 250] as [Int?], 1),
    ([nil, 300, nil, 200] as [Int?], 3),
    ([150, 90] as [Int?], 1),
    ([101, nil, nil, nil] as [Int?], 0),
])
func picksTheCandidateTheRuleNames(byteCounts: [Int?], expectedIndex: Int) {
    let winner = CandidateSelection.winner(among: byteCounts, budgetBytes: 100)
    #expect(winner?.index == expectedIndex)
    #expect(winner?.byteCount == byteCounts[expectedIndex])
}

@Test(arguments: [[nil, nil, nil, nil] as [Int?], [] as [Int?]])
func hasNoWinnerWithoutASuccessfulCandidate(byteCounts: [Int?]) {
    #expect(CandidateSelection.winner(among: byteCounts, budgetBytes: 100) == nil)
}
