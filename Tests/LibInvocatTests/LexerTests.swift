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
        regexReject(" a", .name,    ".name shouldn't match a leading space")
        regexReject("a ", .name,    ".name shouldn't match a trailing space")
        regexMatch("a", .name,      ".name should match single characters")
        regexMatch("a  c,", .name,  ".name should allow internal whitespace")
        regexMatch("a b_c", .name,  ".name should allow some punctuation")
    }
    
    // Helper function to compare the token types returned by lexing
    // with an expected set.
    func checkTypes(_ text: String, _ expected: [TokenType]) {
        let lex = Lexer(text: text)
        let types: [TokenType] = lex.getTokens().map{ $0.type }
        XCTAssertEqual(types, expected, "Unexpected token types: \(text)")
    }
    
    func testLexing() {
        var text: String
        var expected: [TokenType]
        
        text = "artifact :: a (fixed quality) (weapon)"
        expected = [.name, .define, .name, .white, .lparen, .name, .rparen,
                    .white, .lparen, .name, .rparen, .newline]
        checkTypes(text, expected)
        
        text = "fixed quality <- gleaming | dull "
        expected = [.name, .select, .name, .pipe, .name, .white, .newline]
        checkTypes(text, expected)
        
        // Note .comment tokens are not emitted by the lexer
        text = "weapon :! sword | axe -- a comment"
        expected = [.name, .defEval, .name, .pipe, .name, .white, .newline]
        checkTypes(text, expected)
        
        text = "weapon <! {artifact} \\n"
        expected = [.name, .selEval, .lbrace, .name, .rbrace, .white,
                    .escape, .newline]
        checkTypes(text, expected)
    }
}
