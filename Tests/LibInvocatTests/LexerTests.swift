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
    
    // Helper function to compare the token types returned by lexing
    // with an expected set.
    func checkTypes(_ text: String, _ expected: [TokenType]) {
        let tokens: [Token] = Lexer(text: text).getTokens()
        let types: [TokenType] = tokens.map{ $0.type }
        XCTAssertEqual(types, expected,
            "Unexpected token types in <\(text)>\n" +
            "\(tokens.map{ $0.description })")
    }
    
    func testOperators() {
        var text: String
        var expected: [TokenType]
        
        // Operators consume whitespace but it's significant between parens
        text = "artifact :: a (fixed quality) (weapon)"
        expected = [.name, .define, .name, .white, .lparen, .name, .rparen,
                    .white, .lparen, .name, .rparen, .newline]
        checkTypes(text, expected)
        
        // Pipes consume whitespace
        text = "fixed quality <- gleaming | dull "
        expected = [.name, .select, .name, .pipe, .name, .white, .newline]
        checkTypes(text, expected)
        
        // EvaluatingSelection operator
        text = "weapon <! {artifact}"
        expected = [.name, .selEval, .lbrace, .name, .rbrace, .newline]
        checkTypes(text, expected)

        // EvaluatingDefine operator
        text = "weapon :! sword | axe"
        expected = [.name, .defEval, .name, .pipe, .name, .newline]
        checkTypes(text, expected)
    }

    func testEscapesAndSplit() {
        var text: String
        var expected: [TokenType]

        // More operators and escape characters
        text = "weapon <! {artifact} \\n"
        expected = [.name, .selEval, .lbrace, .name, .rbrace, .white,
                    .escape, .newline]
        checkTypes(text, expected)

        // Check split
        text = "a long line \\"
        expected = [.name, .white, .split, .newline]
        checkTypes(text, expected)
    }

    func testCommentsAndRules() {
        var text: String
        var expected: [TokenType]

        // Note .comment tokens are not emitted by the lexer
        text = "weapon :! sword | axe -- a comment"
        expected = [.name, .defEval, .name, .pipe, .name, .white, .newline]
        checkTypes(text, expected)

        // Check rule1 and rule2
        text = "-----------\n==========="
        expected = [.rule1, .newline, .rule2, .newline]
        checkTypes(text, expected)
    }

    func testNumbers() {
        var text: String
        var expected: [TokenType]

        // Numbers must appear before names or they are eaten
        text = "1 time"
        expected = [.number, .white, .name, .newline]
        checkTypes(text, expected)

        // Numbers in the middle of a line are grouped with names
        text = "Times 1"
        expected = [.name, .newline]
        checkTypes(text, expected)
    }
}
