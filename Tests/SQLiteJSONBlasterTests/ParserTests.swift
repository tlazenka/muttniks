import MuttniksParsers
import Testing

@Test func parseInputTracksCharactersAndOffsets() {
    let input = CharStream("éx")
    #expect(input.offset == 0)
    #expect(input.current == "é")

    let next = input.advance()
    #expect(next.offset == 1)
    #expect(next.current == "x")
    #expect(next.advance().isAtEnd)
}

@Test func characterLiteralConsumesExactlyOneCharacter() throws {
    let (value, rest) = try const("a" as Character).parse(CharStream("abc")).get()
    #expect(value == "a")
    #expect(rest.offset == 1)
    #expect(rest.current == "b")
}

@Test func characterLiteralFailureDoesNotConsumeInput() {
    switch const("a" as Character).parse(CharStream("xbc")) {
    case .success:
        Issue.record("Expected literal to fail")
    case .failure(let error):
        #expect(error == ParseError(offset: 0, expected: "'a'"))
    }
}

@Test func stringLiteralReportsPartialMatchOffset() {
    switch const("abcd").parse(CharStream("abXd")) {
    case .success:
        Issue.record("Expected literal to fail")
    case .failure(let error):
        #expect(error == ParseError(offset: 2, expected: "'abcd'"))
    }
}

@Test func prefixRequiresAtLeastOneCharacter() throws {
    let parser = regex(while: { $0.isNumber }, expected: "digits")
    let (digits, rest) = try parser.parse(CharStream("123x")).get()
    #expect(digits == "123")
    #expect(rest.offset == 3)

    switch parser.parse(CharStream("x123")) {
    case .success:
        Issue.record("Expected prefix to fail")
    case .failure(let error):
        #expect(error == ParseError(offset: 0, expected: "digits"))
    }
}

@Test func mapTransformsWithoutChangingConsumption() throws {
    let parser = const("a" as Character).map { String($0).uppercased() }
    let (value, rest) = try parser.parse(CharStream("ab")).get()
    #expect(value == "A")
    #expect(rest.offset == 1)
}

@Test func flatMapSequencesParsers() throws {
    let parser = const("a" as Character).flatMap { _ in const("b" as Character) }
    let (value, rest) = try parser.parse(CharStream("abc")).get()
    #expect(value == "b")
    #expect(rest.offset == 2)
}

@Test func oneOfRetriesEveryAlternativeFromOriginalInput() throws {
    let parser = oneOf([const("abx"), const("abc")])
    let (value, rest) = try parser.parse(CharStream("abc!")).get()
    #expect(value == "abc")
    #expect(rest.offset == 3)
}

@Test func oneOfReturnsFurthestFailure() {
    let parser = oneOf([const("ax"), const("abcx"), const("abz")])
    switch parser.parse(CharStream("abcd")) {
    case .success:
        Issue.record("Expected alternatives to fail")
    case .failure(let error):
        #expect(error.offset == 3)
        #expect(error.expected == "'abcx'")
    }
}

@Test func oneOfUsesLaterFailureWhenOffsetsTie() {
    let parser = oneOf([const("a" as Character), const("b" as Character)])
    switch parser.parse(CharStream("x")) {
    case .success:
        Issue.record("Expected alternatives to fail")
    case .failure(let error):
        #expect(error == ParseError(offset: 0, expected: "'b'"))
    }
}

@Test func manyStopsAtFirstFailureWithoutConsumingIt() throws {
    let parser = many(const("a" as Character))
    let (values, rest) = try parser.parse(CharStream("aaab")).get()
    #expect(values == ["a", "a", "a"])
    #expect(rest.offset == 3)
    #expect(rest.current == "b")
}

@Test func manySucceedsWithEmptyArray() throws {
    let (values, rest) = try many(const("a" as Character)).parse(CharStream("bbb")).get()
    #expect(values.isEmpty)
    #expect(rest.offset == 0)
}

@Test func manyStopsWhenChildSucceedsWithoutProgress() throws {
    let noProgress = Parser<Int> { input in .success((32, input)) }
    let (values, rest) = try many(noProgress).parse(CharStream("abc")).get()
    #expect(values.isEmpty)
    #expect(rest.offset == 0)
}

@Test func whitespaceAcceptsZeroOrMoreWhitespaceCharacters() throws {
    let (_, untouched) = try whitespace.parse(CharStream("abc")).get()
    #expect(untouched.offset == 0)

    let (_, consumed) = try whitespace.parse(CharStream(" \n\tabc")).get()
    #expect(consumed.offset == 3)
    #expect(consumed.current == "a")
}

@Test func tokenConsumesLeadingAndTrailingWhitespace() throws {
    let (value, rest) = try token(const("abc")).parse(CharStream(" \tabc \nxyz")).get()
    #expect(value == "abc")
    #expect(rest.current == "x")
    #expect(rest.offset == 7)
}
