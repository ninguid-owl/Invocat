//
//  LexerTests.swift
//  LibInvocat
//
//

import XCTest
@testable import LibInvocat

class LexerTests: XCTestCase {
    
    func regexMatch(_ str: String, _ type: TokenType, _ message: String) {
        let regex = "^\(type.rawValue)$"
        let range = str.range(of: regex, options: .regularExpression)
        XCTAssertNotNil(range, message)
    }
    
    func regexReject(_ str: String, _ type: TokenType, _ message: String) {
        let regex = "^\(type.rawValue)$"
        let range = str.range(of: regex, options: .regularExpression)
        XCTAssertNil(range, message)
    }

    func testNameRegex() {
        regexReject(" a",   .name,  ".name shouldn't match a leading space")
        regexReject("a ",   .name,  ".name shouldn't match a trailing space")
        regexMatch("a",     .name,  ".name should match single characters")
        regexMatch("a  c,", .name,  ".name should allow internal whitespace")
        regexMatch("a b_c", .name,  ".name should allow some punctuation")
        regexMatch("a 1",   .name,  ".name should allow numbers")
    }
    
    // Compares the token types returned by lexing with an expected set.
    func checkTypes(_ text: String, _ expected: [TokenType]) {
        let tokens: [Token] = Lexer.tokens(from: text)
        let types: [TokenType] = tokens.map{ $0.type }
        XCTAssertEqual(types, expected,
            "Unexpected token types in <\(text)>\n" +
            "\(tokens.map{ $0.description })")
    }

    // Compares the lexems returned by lexing with an expected set.
    func checkLexemes(_ text: String, _ expected: [String]) {
        let tokens: [Token] = Lexer.tokens(from: text)
        let lexemes: [String] = tokens.map{ $0.lexeme }
        XCTAssertEqual(lexemes, expected,
            "Unexpected lexemes in <\(text)>\n" +
            "<\(lexemes.map{ $0.description })>")
    }
    
    func testOperators() {
        var text: String
        var expectedTypes: [TokenType]
        var expectedLexemes: [String]
        
        // Operators consume whitespace but it's significant between parens
        text = "artifact :: a (fixed quality) (weapon)"
        expectedTypes = [.name, .define, .name, .white, .lparen, .name, .rparen,
                         .white, .lparen, .name, .rparen, .eof]
        expectedLexemes = ["artifact", "::", "a", " ", "(", "fixed quality",
                           ")", " ", "(", "weapon", ")", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)
        
        // Pipes consume whitespace
        text = "fixed quality <- gleaming | dull "
        expectedTypes = [.name, .select, .name, .pipe, .name, .white, .eof]
        expectedLexemes = ["fixed quality", "<-", "gleaming", "|", "dull", " ", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)
        
        // EvaluatingSelection operator
        text = "weapon <! {artifact}"
        expectedTypes = [.name, .selEval, .lbrace, .name, .rbrace, .eof]
        expectedLexemes = ["weapon", "<!", "{", "artifact", "}", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)

        // EvaluatingDefine operator
        text = "weapon :! sword | axe"
        expectedTypes = [.name, .defEval, .name, .pipe, .name, .eof]
        expectedLexemes = ["weapon", ":!", "sword", "|", "axe", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)
    }

    func testEscapes() {
        var text: String
        var expectedTokens: [TokenType]
        var expectedLexemes: [String]

        // More operators and escape characters
        text = "weapon <! {artifact} \\n"
        expectedTokens = [.name, .selEval, .lbrace, .name, .rbrace, .white, .escape, .eof]
        expectedLexemes = ["weapon", "<!", "{", "artifact", "}", " ", "\n", ""]
        checkTypes(text, expectedTokens)
        checkLexemes(text, expectedLexemes)

        // Check escaping backslash
        text = "escape a backslash \\\\"
        expectedTokens = [.name, .white, .escape, .eof]
        expectedLexemes = ["escape a backslash", " ", "\\", ""]
        checkTypes(text, expectedTokens)
        checkLexemes(text, expectedLexemes)
    }

    func testSplit() {
        var text: String
        var expected: [TokenType]

        // Check split is consumed
        text = "a long line\\" + "\na continuation"
        expected = [.name, .name, .eof]
        checkTypes(text, expected)

        // Check trailing space is preserverd with split
        text = "a long line      \\" + "\na continuation"
        expected = [.name, .white, .name, .eof]
        checkTypes(text, expected)
    }

    func testCommentsAndRules() {
        var text: String
        var expected: [TokenType]

        // Note .comment tokens are not emitted by the lexer
        text = "weapon :! sword | axe -- a comment"
        expected = [.name, .defEval, .name, .pipe, .name, .eof]
        checkTypes(text, expected)

        // Check rule1 and rule2
        text = "-----------\n==========="
        expected = [.rule1, .newline, .rule2, .eof]
        checkTypes(text, expected)

        // Comments are single-line only and eat leading whitespace.
        text = "  -- " + "\nsomething here"
        expected = [.newline, .name, .eof]
        checkTypes(text, expected)
    }

    func testNewline() {
        var text: String
        var expectedTypes: [TokenType]
        var expectedLexemes: [String]

        // Newlines consume leading whitespace
        text = "   \nnowhere"
        expectedTypes = [.newline, .name, .eof]
        expectedLexemes = ["\n", "nowhere", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)
    }

    func testNumbers() {
        var text: String
        var expected: [TokenType]

        // Numbers must appear before names or they are eaten
        text = "1 time"
        expected = [.number, .white, .name, .eof]
        checkTypes(text, expected)

        // Numbers in the middle of a line are grouped with names
        text = "Times 1"
        expected = [.name, .eof]
        checkTypes(text, expected)
    }

    func testDN() {
        var text: String
        var expected: [TokenType]

        // A dN can be followed by either two spaces ...
        text = "d20  Shipwrecked"
        expected = [.dN, .name, .eof]
        checkTypes(text, expected)

        // ... or a apace and punctuation.
        text = "d20 / Shipwrecked"
        expected = [.dN, .name, .eof]
        checkTypes(text, expected)

        // Otherwise, it's just a name.
        text = "d20 Shipwrecked"
        expected = [.name, .eof]
        checkTypes(text, expected)

        text = "d4"
        expected = [.name, .eof]
        checkTypes(text, expected)
    }

    func testWeights() {
        var text: String
        var expectedTypes: [TokenType]
        var expectedLexemes: [String]

        // A weight is a number or range followed by at least 2 spaces ...
        text = "1    2 silver coins"
        expectedTypes = [.weight, .number, .white, .name, .eof]
        checkTypes(text, expectedTypes)

        text = "2-6  knotted threads"
        expectedTypes = [.weight, .name, .eof]
        checkTypes(text, expectedTypes)

        // ... or a space and a punctuation mark.
        text = "1 - 2 silver coins"
        expectedTypes = [.weight, .number, .white, .name, .eof]
        checkTypes(text, expectedTypes)

        // This is a number.
        text = "1 time"
        expectedTypes = [.number, .white, .name, .eof]
        checkTypes(text, expectedTypes)

        // Check that .weight lexemes are properly trimmed.
        text = "1  "
        expectedTypes = [.weight, .eof]
        expectedLexemes = ["1", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)

        text = "2-20 / "
        expectedTypes = [.weight, .eof]
        expectedLexemes = ["2-20", ""]
        checkTypes(text, expectedTypes)
        checkLexemes(text, expectedLexemes)
    }

    // Enumerate tests for Linux
    static var allTests = [
        ("testNameRegex", testNameRegex),
        ("testOperators", testOperators),
        ("testEscapes", testEscapes),
        ("testSplit", testSplit),
        ("testCommentsAndRules", testCommentsAndRules),
        ("testNewline", testNewline),
        ("testNumbers", testNumbers),
        ("testDN", testDN),
        ("testWeights", testWeights),
    ]
}
