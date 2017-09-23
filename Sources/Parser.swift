//
//  Parser.swift
//  LibInvocat
//
//  TODO: Better errors. Throw instead of fatalError.
//  TODO: Set access levels on parser functions
//  TODO: formalize concrete syntax
//
//

/// A parser for the Invocat language.
class Parser {

    private var current = 0
    private var tokens: [Token] = []

    /// Returns an array of Invocat expressions given an array of lexical
    /// tokens.
    func parse(tokens: [Token]) -> [InvExp] {
        self.current = 0
        self.tokens = tokens
        var expressions: [InvExp] = []

        // As long as there's a token to examine, consume newlines and try to
        // get a new expression.
        while current < tokens.count {
            takeNewlines()
            if peek(.eof) { break }
            guard let exp = expression() else {
                fatalError(errorText("Could not parse expression."))
            }
            expressions.append(exp)
        }
        return expressions
    }

    /// Returns the token at `index` or `nil` if the index is invalid.
    func token(at index: Int? = nil) -> Token? {
        let index = index ?? current
        return tokens.indices.contains(index) ? tokens[index] : nil
    }

    /// Consumes and returns the current token if it matches one of the provided
    /// types.
    ///
    /// - Parameter types: A list of TokenTypes to match.
    @discardableResult
    func take(_ types: TokenType...) -> Token? { return take(types) }

    /// Consumes and returns the current token if it matches one of the provided
    /// types.
    ///
    /// - Parameter types: An array of TokenTypes to match.
    @discardableResult
    func take(_ types: [TokenType]) -> Token? {
        if let token = token(at: current), types.contains(token.type) {
            current += 1
            return token
        }
        return nil
    }

    /// Returns `true` if the current token matches any of the provided types.
    func peek(_ types: TokenType...) -> Bool { return peek(types) }

    /// Returns `true` if the current token matches any of the provided types.
    func peek(_ types: [TokenType]) -> Bool {
        if let token = token(at: current) {
            return types.contains(token.type)
        }
        return false
    }

    /// Consumes and returns the next `n` tokens if they match the provided
    /// types; returns `nil` otherwise.
    ///
    /// - Parameter types: An array of token types to match in order starting
    ///   with the current token.
    func seq(_ types: TokenType...) -> [Token]? { return seq(types) }

    /// Consumes and returns the next `n` tokens if they match the provided
    /// types; returns `nil` otherwise.
    ///
    /// - Parameter types: A sequence of token types to match in order starting
    ///   with the current token.
    func seq(_ types: [TokenType]) -> [Token]? {
        let last = current + types.count
        if  last > tokens.count { return nil }
        let actual = tokens[current..<last].map{ $0.type }
        if  types == actual {
            return types.map{ take($0)! }
        }
        return nil
    }

    /// Returns true if the previous token matches the given token type.
    ///
    /// - Parameter type: The token type to look for.
    func prev(_ type: TokenType) -> Bool {
        if let token = token(at: current-1) {
            return type == token.type
        }
        return false
    }

    /// Consumes all consecutive newline tokens.
    func takeNewlines() {
        while peek(.newline) { take(.newline) }
    }

    /// Returns an Invocat expression or `nil` if an expression can't be
    /// created from the current sequence of tokens.
    ///
    /// Tries to form an expression by testing each of the expression types
    /// described in the abstract syntax.
    func expression() -> InvExp? {
        return definition()           ??    // name :: items
               selection()            ??    // name <- items
               evaluatingDefinition() ??    // name :! items
               evaluatingSelection()  ??    // name <! items
               mix()                        // literal|reference|draw  mix
    }

    /// Returns a `.definition` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// Definitions can be made with the `.define` operator or with special
    /// table syntax. Invocat supports two table types.
    func definition() -> InvExp? {
        if let def = table1() ?? table2() {
            return def
        }
        guard let name = seq(.name, .define)?.first else {
            return nil
        }
        return InvExp.definition(name.lexeme, items())
    }

    /// Returns a `.selection` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A selection begins with a `.name` followed by the `.select` operator and
    /// a list of expressions.
    func selection() -> InvExp? {
        guard let name = seq(.name, .select)?.first else {
            return nil
        }
        return InvExp.selection(name.lexeme, items())
    }

    /// Returns an `.evaluatingDefinition` expression or `nil` if the expression
    /// can't be created from the current sequence of tokens.
    ///
    /// An evaluatingDefinition begins with a `.name` followed by the `.defEval`
    /// operator and a list of expressions.
    func evaluatingDefinition() -> InvExp? {
        guard let name = seq(.name, .defEval)?.first else {
            return nil
        }
        return InvExp.evaluatingDefinition(name.lexeme, items())
    }

    /// Returns an `.evaluatingSelection` expression or `nil` if the expression
    /// can't be created from the current sequence of tokens.
    ///
    /// An evaluatingSelection begins with a `.name` followed by the `.selEval`
    /// operator and a list of expressions.
    func evaluatingSelection() -> InvExp? {
        guard let name = seq(.name, .selEval)?.first else {
            return nil
        }
        return InvExp.evaluatingSelection(name.lexeme, items())
    }

    /// Returns a `.reference`, `.draw`, `.literal`, or `.mix` expression; or
    /// `nil` if the expression can't be created from the current sequence of
    /// tokens.
    ///
    /// A mix combines one or more adjacent references, draws, and literals,
    /// terminating at `separator`.
    ///
    /// - Parameter terminator: The token type on which to end the mix.
    func mix(terminatedBy terminator: TokenType = .pipe) -> InvExp? {
        guard var exp1 = reference() ?? draw() ?? literal() else {
            return nil
        }

        // If the separator is rule1, attempt to conusme a newline and if the
        // next token isn't the separator, join the next expression with a
        // space.
        if terminator == .rule1, let _ = take(.newline) {
            take(.white) // Consume leading white in a table2
            if !peek(terminator) {
                exp1 = InvExp.mix(exp1, InvExp.literal(" "))
            }
        }

        // Return exp1 if at a terminator token, eof, or newline.
        if let _ = take(terminator) {
            // .rule1 is always followed by .newline
            if terminator == .rule1 { take(.newline) }
            return exp1
        }
        if peek(.eof, .newline) {
            return exp1
        }

        guard let exp2 = mix(terminatedBy: terminator) else {
            fatalError(errorText("Expected second expression in mix."))
        }
        return InvExp.mix(exp1, exp2)
    }

    /// Returns a `.reference` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A reference is an InvExp surrounded by parentheses.
    func reference() -> InvExp? {
        let start = current
        guard let _ = take(.lparen), let nameExp = mix(terminatedBy: .rparen) else {
            current = start     // rewind the stack
            return nil
        }
        // Verify the last token was a right paren and not EOF or newline.
        return prev(.rparen) ? InvExp.reference(nameExp) : nil
    }

    /// Returns a `.draw` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A draw is an InvExp surrounded by braces.
    func draw() -> InvExp? {
        let start = current
        guard let _ = take(.lbrace), let nameExp = mix(terminatedBy: .rbrace) else {
            current = start     // rewind the stack
            return nil
        }
        // Verify the last token was a right brace and not EOF or newline.
        return prev(.rbrace) ? InvExp.draw(nameExp) : nil
    }

    /// Returns a `.literal` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A literal is a `.name`, `.number`, '.punctuation`, `.escape`, or
    /// `.white`, optionally followed by another literal.
    /// A literal now also includes `.dN` and `.weight` when they are not
    /// part of a definition. This means that we must attempt to match
    /// definitions before literals.
    func literal() -> InvExp? {
        let types: [TokenType] = [.name, .number, .punct, .escape, .white,
                                  .dN, .weight, .symbol]
        if !peek(types) { return nil }
        
        var value: String = ""
        repeat {
            if let token = take(types) {
                value = value.appending(token.lexeme)
            }
        } while peek(types)
        return InvExp.literal(value)
    }

    /// Captures a list of expressions and return them in an array.
    ///
    /// - Parameters:
    ///   - separatedBy: The `TokenType` expected between each
    ///     expression. The default is `.pipe`.
    ///   - weightedBy: The `WeightType` of the items list. Determines how any
    ///     `.weight` tokens are converted into numeric values.
    func items(separatedBy separator: TokenType = .pipe,
               weightedBy weighting: WeightType = .frequency) -> [InvExp] {
        var exps: [InvExp] = []
        repeat {
            // Ignore leading whitespace within items.
            take(.white)
            // Capture the optional weight; defaults to 1.
            let wt = weighting.magnitude(token: take(.weight))
            guard let exp = mix(terminatedBy: separator) else {
                fatalError(errorText("Expected expression parsing items."))
            }
            // Weighting semantics are that an item with weight n is added
            // to the array n times. This approach keeps things very simple.
            // If it proves to be too expensive, we can reconsider it.
            exps.append(contentsOf: Array(repeating: exp, count: wt))
        } while take(.newline, .eof) == nil  // Repeat until newline or eof
        return exps
    }

    /// Returns a `.definition` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A table1 is a `.name`, `.newline`, and `.rule1`, followed by items on
    /// consecutive lines.
    ///
    /// Inside a table1 the only legal sequences are `item .newline`, or
    /// `.newline .newline`. Two consecutive newlines terminate the list.
    ///
    ///     name
    ///     --------
    ///     option 1
    ///     option 2
    ///
    func table1() -> InvExp? {
        let name: Token
        let weighting: WeightType
        if let n = seq(.name, .newline, .rule1, .newline)?.first {
            name = n
            weighting = .frequency
        }
        else if let n = seq(.dN, .name, .newline, .rule1, .newline)?[1] {
            name = n
            weighting = .die
        }
        else { return nil }
        let items = self.items(separatedBy: .newline, weightedBy: weighting)
        return InvExp.definition(name.lexeme, items)
    }

    /// Returns a `.definition` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A table2 is a `.name`, `.newline`, and `.rule2`, followed by a list of
    /// rule1-separated items.
    ///
    /// Two consecutive newlines terminates the list.
    ///
    ///     name
    ///     ==========
    ///     multi-line
    ///     expression
    ///     ----------
    ///     second opt
    ///     ----------
    ///
    func table2() -> InvExp? {
        let name: Token
        let weighting: WeightType
        if let n = seq(.name, .newline, .rule2, .newline)?.first {
            name = n
            weighting = .frequency
        }
        else if let n = seq(.dN, .name, .newline, .rule2, .newline)?[1] {
            name = n
            weighting = .die
        }
        else { return nil }
        let items = self.items(separatedBy: .rule1, weightedBy: weighting)
        return InvExp.definition(name.lexeme, items)
    }

    /// Provides basic info for error messages including the current token.
    ///
    /// - TODO: Add more info. Unwrap the optional.
    func errorText(_ msg: String) -> String {
        let token = String(describing: self.token(at: current))
        return "\(msg)\nCurrent token: \(String(describing: token))"
    }
}
