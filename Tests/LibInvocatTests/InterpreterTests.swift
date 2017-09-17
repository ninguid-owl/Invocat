//
//  InterpreterTests.swift
//  LibInvocat
//

import XCTest
@testable import LibInvocat

class InterpreterTests: XCTestCase {
    var interpreter: Interpreter = Interpreter()

    override func setUp() {
        super.setUp()
        interpreter = Interpreter()
    }

    func checkCases(_ cases: [(test: String, expected: String?)]) {
        for (test, expected) in cases {
            let result = interpreter.eval(text: test)?[0]
            XCTAssertEqual(result , expected,
                           "\ninput: [\(test)]\nresult: [\(result ?? "nil")]" +
                           "\nexpected: [\(expected ?? "nil")]")
        }
    }

    func testComments() {
        let cases: [(test: String, expected: String?)] = [
            ("-- shh", nil),
            ("the text -- a comment", "the text"),
            ("a dash--like this", "a dash--like this"),
        ]
        checkCases(cases)
    }

    // TODO ------------------------------------------------------------------------
    // Enumerate tests for Linux
    static var allTests = [
        ("testComments", testComments),
    ]
}
