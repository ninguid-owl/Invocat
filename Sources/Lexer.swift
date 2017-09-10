//
//  Lexer.swift
//  LibInvocat
//
//  Created by Matthew Antoun on 2017-09-09.
//
//

typealias SRange = Range<String.Index>

enum TokenType: String {
    case name    = "[\\w_!'?.,;]+"  // Allow some punctuation. TODO: consider space
    case number  = "[\\d]+"
    
    case lparen  = "[(]"
    case rparen  = "[)]"
    case lbrace  = "[{]"
    case rbrace  = "[}]"
    case pipe    = "[|]"            // TODO: surround with white?
    
    case define  = "[:]{2}"         // TODO: capture space before?
    case defEval = "[:][!]"         // ...
    case select  = "[<][-]"
    case selEval = "[<][!]"
    
    case comment = "[-]{2}\\s+.*$"
    case rule1   = "[-]{3,}.*$"
    case rule2   = "[=]{3,}.*$"
    
    case white   = "[\\s]+"
    case escape  = "\\\\[n(){}]"    // Could add r, t, etc.
    case split   = "\\\\$"
    case punct   = "[\\p{Punctuation}]"
    case newline = "[\\\\n]"
    
    // Provide a way to iterate over the cases in order
    static let all = [
        name, number,
        lparen, rparen, lbrace, rbrace, pipe,
        define, defEval, select, selEval,
        comment, rule1, rule2,
        white, escape, split, punct, newline
    ]
}

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

struct Lexer {
    let text: String
    
    func getTokens() -> [Token] {
        var tokens: [Token] = []
        
        // Separate the text by newlines. This makes it very easy to
        // strip leading and trailing whitespace but means we have to
        // manually add a newline token each time through the loop.
        // TODO: Consider just letting the regex handle the newline.
        let lines = text.components(separatedBy: .newlines)
        
        // TODO: Trim leading and trailing whitespace?
        //lines = lines.map{ $0.trimmingCharacters(in: .whitespaces)}
        
        for (line, text) in lines.enumerated() {
            var range = text.startIndex..<text.endIndex
            
            while !range.isEmpty {
                // Get the next token and then narrow the search range
                // using the token's end position.
                let (token, bounds) = nextToken(on: line, from: text, in: range)
                range = bounds.upperBound..<text.endIndex
                if token.type != .comment {
                    tokens.append(token)
                }
            }
            tokens.append(Token(type: .newline, lexeme: "", line: line))
        }
        return tokens
    }
    
    func nextToken(on line: Int, from text: String, in window: SRange) -> (Token, SRange) {
        // Try to match each token type using its regular expression
        // within the window.
        for type in TokenType.all {
            let regex = "^\(type.rawValue)"  // Anchor to beginning of the range
            if let range = text.range(of: regex, options: .regularExpression, range: window) {
                let token = Token(type: type, lexeme: text[range], line: line)
                return (token, range)
            }
        }
        fatalError("Nothing matched: \(text[window])")
    }
}
