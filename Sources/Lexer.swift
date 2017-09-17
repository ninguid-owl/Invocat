//
//  Lexer.swift
//  LibInvocat
//
//

typealias Bounds = Range<String.Index>

/// The types of tokens emitted by the lexer.
///
/// The `rawValue` of each case is a regex that defines the allowable lexemes
/// for that type.
/// - Note: The regex is intended to be anchored when matching.
/// - Note: Some lexemes are accepted by the regexes of mutliple cases.
///         Therefore, the order in which the cases are tested is important.
enum TokenType: String {

    // Names are one or more alphanumeric characters and some symbols
    // with spaces between. They cannot end with a space.
    // Names include numbers so check for number first.
    case number  = "[\\d]+"
    case name    = "[\\w_!'?.,;]+( +[\\w_!'?.,;]+)*"
    
    case lparen  = "[(]"
    case rparen  = "[)]"
    case lbrace  = "[{]"
    case rbrace  = "[}]"

    // These operators consume the whitespace before and after them.
    case pipe    = "[\\p{Blank}]*[|][\\p{Blank}]*"
    case define  = "[\\p{Blank}]*[:]{2}[\\p{Blank}]*"   // ::
    case defEval = "[\\p{Blank}]*[:][!][\\p{Blank}]*"   // :!
    case select  = "[\\p{Blank}]*[<][-][\\p{Blank}]*"   // <-
    case selEval = "[\\p{Blank}]*[<][!][\\p{Blank}]*"   // <!
    

    case comment = "\\p{Blank}*[-]{2}\\p{Blank}+.*"
    case rule1   = "[-]{3,}.*"              // TODO: consume newlines?
    case rule2   = "[=]{3,}.*"

    case split   = "[\\\\][\\v]"            // \ and vertical whitespace
    case newline = "[\\p{Blank}]*[\\n]"     // newlines eat preceding whitespace
    case white   = "[\\s]+"
    case escape  = "\\\\[nrt(){}|\\\\]"
    case punct   = "[\\p{Punctuation}]"     // TODO: What is this used for?

    case eof     = ""

    /// Provides a way to iterate over the cases to be tested in order.
    static let all = [
        number, name,
        lparen, rparen, lbrace, rbrace,
        pipe, define, defEval, select, selEval,
        comment, rule1, rule2,
        split, newline, white, escape, punct
    ]

    // TODO: define match method here?
}

/// A token in Invocat's lexical syntax.
///
/// A `Token` encapsulates a type, the actual lexeme that was matched, and the
/// number of the line on which it was matched.
struct Token {
    let type: TokenType
    let lexeme: String
    let line: Int
}

extension Token: CustomStringConvertible {
    var description: String {
        switch type {
        case .name, .number, .comment, .escape, .punct:
            return "\(type)(\(lexeme))"
        default:
            return "\(type)"
        }
    }
}

/// A lexer for the Invocat language.
struct Lexer {

    /// Scans the `text` and returns an array of `Tokens`.
    ///
    /// - Note: Comments and line split tokens are discarded.
    static func tokens(from text: String) -> [Token] {
        var tokens: [Token] = []
        var range = text.startIndex..<text.endIndex  // The search window
        var line: Int = 0                            // The current line number

        while !range.isEmpty {
            // Get the next token type and then narrow the search range
            // using the token's end position.
            let (type, bounds) = nextTokenType(from: text, in: range)
            range = bounds.upperBound..<text.endIndex

            if type == .comment || type == .split {
                continue        // Don't add split or comment tokens.
            }
            if type == .newline { line += 1 }
            let token = Token(type: type, lexeme: text[bounds], line: line)
            tokens.append(token)
        }
        // Add the .eof token
        tokens.append(Token(type: .eof, lexeme: "", line: line))
        return tokens
    }

    /// Returns the type and bounds of the first token in search window of the
    /// provided String.
    ///
    /// - Parameter from: The text to search.
    /// - Parameter in: The search window expressed as a `Range` of String
    ///   indices.
    static func nextTokenType(from s: String, in window: Bounds) -> (TokenType, Bounds) {
        // Try to match each token type using its regular expression, which is
        // anchored to the beginning of the range.
        let opts: String.CompareOptions = [.regularExpression, .anchored]
        for type in TokenType.all {
            let regex = type.rawValue
            if let range = s.range(of: regex, options: opts, range: window) {
                return (type, range)
            }
        }
        fatalError("Nothing matched: \(s[window])")
    }
}
