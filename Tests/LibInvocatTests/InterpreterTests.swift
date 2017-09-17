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

    func testMultilines() {
        let cases: [(test: String, expected: String?)] = [
            ("dragon murmurings   \n" +
             "=================   \n" +
             "still having joy    \n" +
             "-----------------   \n" +
             "the bloodline       \n" +
             "is not cut off      \n" +
             "-----------------   \n", nil),
            ("(dragon murmurings)", "still having joy"),
            ("(dragon murmurings)", "the bloodline is not cut off"),
        ]
        checkCases(cases)
    }

    // Enumerate tests for Linux
    static var allTests = [
        ("testComments", testComments),
        ("testMultilines", testMultilines)
    ]
}
