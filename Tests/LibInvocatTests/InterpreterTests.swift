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

    func check(_ cases: [(test: String, expected: String?)]) {
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
        check(cases)
    }

    func testTable1() {
        let cases: [(test: String, expected: String?)] = [
            // Leading whitespace is insignificant in table.
            ("""
             color
             --------
             mazarine
                 cochineal
                     tartrazine
             """, nil),
            ("(color)", "cochineal"),
            ("(color)", "mazarine"),
            ]
        check(cases)
    }

    func testMultilines() {
        let cases: [(test: String, expected: String?)] = [
            // Trailing whitespace is insignificant in table.
            ("dragon murmurings   \n" +
             "=================   \n" +
             "still having joy    \n" +
             "-----------------   \n" +
             "the bloodline       \n" +
             "is not cut off      \n" +
             "-----------------   \n", nil),
            ("(dragon murmurings)", "still having joy"),
            ("(dragon murmurings)", "the bloodline is not cut off"),
            // Leading whitespace is insignificant in table.
            ("eyeballs in a skull   \n" +
             "===================   \n" +
             "       still having   \n" +
             "      consciousness   \n" +
             "-------------------   \n" +
             "       not dried up   \n" +
             "-------------------   \n", nil),
            ("(eyeballs in a skull)", "not dried up"),
            ("(eyeballs in a skull)", "still having consciousness"),
            // Whitespace is not consumed in the middle of a mix.
            ("""
             season :: fall | winter | spring | summer
             d4  memory
             =================
             1  that (season),
                it disappeared.
             -----------------

             (memory)
             """, "that summer, it disappeared.")
        ]
        check(cases)
    }

    // Enumerate tests for Linux
    static var allTests = [
        ("testComments", testComments),
        ("testTable1", testTable1),
        ("testMultilines", testMultilines)
    ]
}
