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

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

    // TODO: recognize [19]
    // TODO: blank lines and blank first line
    // TODO: test escapes are rendered correctly
    // TODO: error on unclosed paren or brace

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
        let text = "name\n" +
                   "----\n" +
                   "opt1\n" +
                   "opt2\n"
        let table1items: [InvExp] = [.literal("opt1"), .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table1items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }

    func testTable1End() {
        let text = "name\n" +
                   "----\n" +
                   "opt1\n" +
                   "\n"     +
                   "not in table"
        let table1: InvExp = .definition("name", [.literal("opt1")])
        let expected: [InvExp] = [table1, .literal("not in table")]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        exps.forEach{ print($0) }
        XCTAssertEqual(exps, expected)
    }

    func testTable2() {
        let text = "name\n" +
                   "====\n" +
                   "opt1\n" +
                   "cont\n" +
                   "----\n" +
                   "opt2\n" +
                   "----\n"
        let table2items: [InvExp] = [
            .mix(.mix(.literal("opt1"), .literal(" ")), .literal("cont")),
            .literal("opt2")]
        let expected: [InvExp] = [.definition("name", table2items)]
        let tokens = Lexer.tokens(from: text)
        let exps = parser.parse(tokens: tokens)
        XCTAssertEqual(exps, expected)
    }
}
