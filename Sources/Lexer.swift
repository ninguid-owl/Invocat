//
//  Lexer.swift
//  LibInvocat
//
//

typealias SRange = Range<String.Index>

private var blank = ""
enum TokenType: String {

    // Names are one or more alphanumeric characters and some symbols
    // with spaces between. They cannot end with a space.
    // Names include numbers so check for number first.
    case number  = "[\\d]+"
    case name = "[\\w_!'?.,;]+( +[\\w_!'?.,;]+)*"
    
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
    
    case comment = "[-]{2}\\s+.*$"          // TODO: match the newline too?
    case rule1   = "[-]{3,}.*$"
    case rule2   = "[=]{3,}.*$"
    
    case white   = "[\\s]+"
    case escape  = "\\\\[nrt(){}|]"
    case split   = "\\\\$"
    case punct   = "[\\p{Punctuation}]"     // TODO: What is this used for?
    case newline = "[\\\\n]"
    
    // Provide a way to iterate over the cases in order
    static let all = [
        number, name,
        lparen, rparen, lbrace, rbrace,
        pipe, define, defEval, select, selEval,
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
        let lines = self.text.components(separatedBy: .newlines)
        
        // TODO: Trim leading and trailing whitespace?
        //lines = lines.map{ $0.trimmingCharacters(in: .whitespaces)}
        
        var line: Int       // Keep track of the current line number
        var text: String    // The text from the current line

        // Define a helper function that closes over the line and text vars
        func nextToken(in window: SRange) -> (Token, SRange) {
            // Try to match each token type using its regular expression,
            // which we first anchor to the beginning of the range.
            for type in TokenType.all {
                let regex = "^\(type.rawValue)"
                if let range = text.range(of: regex, options: .regularExpression, range: window) {
                    let token = Token(type: type, lexeme: text[range], line: line)
                    return (token, range)
                }
            }
            fatalError("Nothing matched: \(text[window])")
        }

        for (idx, str) in lines.enumerated() {
            (line, text) = (idx, str)

            var range = text.startIndex..<text.endIndex
            
            while !range.isEmpty {
                // Get the next token and then narrow the search range
                // using the token's end position.
                let (token, bounds) = nextToken(in: range)
                range = bounds.upperBound..<text.endIndex
                if token.type != .comment {
                    tokens.append(token)
                }
            }
            tokens.append(Token(type: .newline, lexeme: "", line: line))
        }
        return tokens
    }
}
