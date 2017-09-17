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
        if types == actual {
            return types.map{ take($0)! }
        }
        return nil
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
    /// A mix combines one or more adjacent references, draws, and literals. If
    /// `multiline` is true, the mix will combine expressions over multiple
    /// lines.
    ///
    /// - Parameter multiline: Whether to allow the expressions to be combined
    ///   to span multiple lines.
    func mix(multiline: Bool = false) -> InvExp? {
        guard var exp1 = reference() ?? draw() ?? literal() else {
            return nil
        }
        if multiline {
            // If we're matching multiline expressions, bail when we see a
            // rule1. Otherwise, join consecutive lines with a single space.
            if seq(.newline, .rule1, .newline) != nil { return exp1 }
            let separator = take(.newline) != nil ? " " : ""
            exp1 = InvExp.mix(exp1, InvExp.literal(separator))
        }
        else if peek(.newline, .eof) || take(.pipe) != nil {
            return exp1
        }
        guard let exp2 = mix(multiline: multiline) else {
            fatalError(errorText("Expected second expression in mix."))
        }
        return InvExp.mix(exp1, exp2)
    }

    /// Returns a `.reference` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A reference is a `.name` surrounded by parentheses: `(name)`
    func reference() -> InvExp? {
        // TODO: test failure on unclosed paren.
        guard let name = seq(.lparen, .name, .rparen)?[1] else {
            return nil
        }
        return InvExp.reference(name.lexeme)
    }

    /// Returns a `.draw` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A draw is a `.name` surrounded by braces: `{name}`
    func draw() -> InvExp? {
        guard let name = seq(.lbrace, .name, .rbrace)?[1] else {
            return nil
        }
        return InvExp.draw(name.lexeme)
    }

    /// Returns a `.literal` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A literal is a `.name`, `.number`, '.punctuation`, `.escape`, or
    /// `.white`, optionally followed by another literal.
    func literal() -> InvExp? {
        let types: [TokenType] = [.name, .number, .punct, .escape, .white]
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
    /// - Parameter multiline: Whether items can be made over multiple lines.
    /// - TODO: Generalize with sepToken, endSeq, errMsg to replace
    ///   table1items() etc.
    func items(multiline: Bool = false) -> [InvExp] {
        var exps: [InvExp] = []
        repeat {
            guard let exp = mix(multiline: multiline) else {
                fatalError(errorText("Expected expression parsing items."))
            }
            exps.append(exp)
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
        guard let name = seq(.name, .newline, .rule1, .newline)?.first else {
            return nil
        }
        return InvExp.definition(name.lexeme, items())
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
        guard let name = seq(.name, .newline, .rule2, .newline)?.first else {
            return nil
        }
        let items = self.items(multiline: true)
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
