//
//  ParserTests.swift
//  LibInvocat
//
//

import XCTest
@testable import LibInvocat

class ParserTests: XCTestCase {

    let parser: Parser = Parser()
    let items: [InvExp] = [
        .mix(.reference("ref"),
             .mix(.literal(" "), .draw("draw")))
    ]

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    func testDefinition() {
        let text = "name :: (ref) {draw}"
        let expected: [InvExp] = [.definition("name", items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testEvalDef() {
        let text = "name :! (ref) {draw}"
        let expected: [InvExp] = [.evaluatingDefinition("name", items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testSelection() {
        let text = "name <- (ref) {draw}"
        let expected: [InvExp] = [.selection("name", items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testEvalSel() {
        let text = "name <! (ref) {draw}"
        let expected: [InvExp] = [.evaluatingSelection("name", items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable1() {
        let text = """
                   name
                   ----
                   opt1
                   opt2
                   """
        let table1items: [InvExp] = [.literal("opt1"), .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table1items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable1End() {
        let text = """
                   name
                   ----
                   opt1

                   not in table
                   """
        let table1: InvExp = .definition("name", [.literal("opt1")])
        let expected: [InvExp] = [table1, .literal("not in table")]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testItems() {
        let text = "animal :: 🐱 | 🦊"
        let opts: [InvExp] = [.literal("🐱"), .literal("🦊")]
        let expected: [InvExp] = [.definition("animal", opts)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable1FrequencyWeighted() {
        let text = """
                   name
                   -------
                   1  opt1
                   1  opt2
                   """
        let table1items: [InvExp] = [.literal("opt1"), .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table1items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable1DieWeighted() {
        let text = """
                   d4   name
                   ----------
                     1  opt1
                   2-4  opt2
                   """
        let table1items: [InvExp] = [.literal("opt1"), .literal("opt2"),
                                     .literal("opt2"), .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table1items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable2() {
        let text = """
                   name
                   ====
                   opt1
                   cont
                   ----
                   opt2
                   ----
                   """
        let table2items: [InvExp] = [
            .mix(.mix(.literal("opt1"), .literal(" ")), .literal("cont")),
            .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table2items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable2FrequencyWeighted() {
        let text = """
                   name
                   =======
                   2  opt1
                      cont
                   -------
                   1  opt2
                   -------
                   """
        let table2items: [InvExp] = [
            .mix(.mix(.literal("opt1"), .literal(" ")), .literal("cont")),
            .mix(.mix(.literal("opt1"), .literal(" ")), .literal("cont")),
            .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table2items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testReference() {
        let text = "(a)"
        let expected: [InvExp] = [.reference("a")]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testDraw() {
        let text = "{a}"
        let expected: [InvExp] = [.draw("a")]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testNestedRefs() {
        let text = "(nested (a))"
        let expected: [InvExp] = [.reference(.mix("nested ", .reference("a")))]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testUnmatchedParen() {
        let text = "((a)}"
        let expected: [InvExp] = [.literal("("), .mix(.reference("a"), .literal("}"))]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)

        exps.forEach { print($0.debugDescription) }
        XCTAssertEqual(exps, expected)
    }

    func testRefsEndWithRParen() {
        // This text is parsed as a series of literals since the parens aren't
        // closed.
        let text = "((a"
        let expected: [InvExp] = [.literal("("), .literal("("), .literal("a")]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testInnerDraw() {
        let text = "(literal {a})"
        let expected: [InvExp] = [.reference(.mix("literal ", .draw("a")))]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    // Enumerate tests for Linux.
    static var allTests = [
        ("testDefinition", testDefinition),
        ("testEvalDef", testEvalDef),
        ("testSelection", testSelection),
        ("testEvalSel", testEvalSel),
        ("testTable1", testTable1),
        ("testTable1End", testTable1End),
        ("testItems", testItems),
        ("testTable1FrequencyWeighted", testTable1FrequencyWeighted),
        ("testTable1DieWeighted", testTable1DieWeighted),
        ("testTable2", testTable2),
        ("testTable2FrequencyWeighted", testTable2FrequencyWeighted),
        ("testReference", testReference),
        ("testDraw", testDraw),
        ("testNestedRefs", testNestedRefs),
        //("testUnmatchedParen", testUnmatchedParen),
        //("testRefsEndWithRParen", testRefsEndWithRParen),
        ("testInnerDraw", testInnerDraw),
    ]
}
