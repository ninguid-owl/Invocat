//
//  Parser.swift
//  LibInvocat
//
//  TODO: Better errors. Throw instead of fatalError.
//  TODO: Set access levels on parser functions
//  TODO: comments must not require blank space after --
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
        self.tokens = tokens
        var expressions: [InvExp] = []

        takeNewlines()     // TODO: Should newlines ever be literals?

        while current < tokens.count && !peek(.eof) {
            // As long as there's a token to examine, get a new expression
            // and consume all following newlines.
            guard let exp = expression() else {
                fatalError(errorText("Could not parse expression."))
            }
            expressions.append(exp)
            takeNewlines()
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
    /// - Parameter types: A list of TokenTypes to match
    @discardableResult
    func take(_ types: TokenType...) -> Token? {
        // If the current token's type matches one of the types provided,
        // consume and return the token.
        if let token = token(at: current), types.contains(token.type) {
            current += 1
            return token
        }
        return nil
    }

    /// Returns `true` if the current token matches any of the provided types.
    func peek(_ types: TokenType...) -> Bool {
        if let token = token(at: current) {
            return types.contains(token.type)
        }
        return false
    }

    /// Consumes and returns the next `n` tokens if they match the provided
    /// types; returns `nil` otherwise.
    ///
    /// - Parameter types: A sequence of token types to match in order starting
    ///   with the current token.
    func seq(_ types: TokenType...) -> [Token]? {
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
        return InvExp.definition(name: name.lexeme, items: items())
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
        return InvExp.selection(name: name.lexeme, items: items())
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
        return InvExp.evaluatingDefinition(name: name.lexeme, items: items())
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
        return InvExp.evaluatingSelection(name: name.lexeme, items: items())
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
            let separator = take(.newline) != nil ? " " : ""
            if peek(.rule1) { return exp1 }
            exp1 = InvExp.mix(item1: exp1, item2: InvExp.literal(literal: separator))
        }
        else if peek(.newline, .pipe, .eof) { return exp1 }
        guard let exp2 = mix(multiline: multiline) else {
            fatalError(errorText("Expected second expression in mix."))
        }
        return InvExp.mix(item1: exp1, item2: exp2)
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
        return InvExp.reference(name: name.lexeme)
    }

    /// Returns a `.draw` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A draw is a `.name` surrounded by braces: `{name}`
    func draw() -> InvExp? {
        guard let name = seq(.lbrace, .name, .rbrace)?[1] else {
            return nil
        }
        return InvExp.draw(name: name.lexeme)
    }

    /// Returns a `.literal` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A literal is a `.name`, `.number`, '.punctuation`, `.escape`, or
    /// `.white`, optionally followed by another literal.
    func literal() -> InvExp? {
        if !peek(.name, .number, .punct, .escape, .white) { return nil }
        
        var value: String = ""
        repeat {
            if let token = take(.name, .number, .punct, .escape, .white) {
                value = value.appending(token.lexeme)
            }
        } while peek(.name, .number, .punct, .escape, .white)
        return InvExp.literal(literal: value)
    }

    /// Captures a list of pipe-separated expressions and return them in an
    /// array.
    ///
    /// - TODO: Restrict to mixes? The abstract syntax allows any expression
    ///   but that's probably not useful.
    /// - TODO: Generalize with sepToken, endSeq, errMsg to replace
    ///   table1items() etc.
    func items() -> [InvExp] {
        var exps: [InvExp] = []
        repeat {
            take(.pipe)
            guard let exp = expression() else {
                fatalError(errorText("Expected expression parsing items."))
            }
            exps.append(exp)
        } while peek(.pipe)
        return exps
    }

    /// Returns a `.definition` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A table1 is a `.name`, `.newline`, and `.rule1`, followed by items on
    /// consecutive lines.
    func table1() -> InvExp? {
        guard let name = seq(.name, .newline, .rule1)?.first else {
            return nil
        }
        return InvExp.definition(name: name.lexeme, items: table1Items())
    }

    /// Returns a `.definition` expression or `nil` if the expression can't be
    /// created from the current sequence of tokens.
    ///
    /// A table2 is a `.name`, `.newline`, and `.rule2`, followed by a list of
    /// rule1-separated items.
    func table2() -> InvExp? {
        guard let name = seq(.name, .newline, .rule2)?.first else {
            return nil
        }
        return InvExp.definition(name: name.lexeme, items: table2Items())
    }

    /// Captures a list of newline-separated expressions and returns them in an
    /// array.
    ///
    /// Once you're in a table1 the only legal sequences are `.mix .newline`, or
    /// `.newline .newline`. Two consecutive newlines terminate the list.
    ///
    ///     name
    ///     --------
    ///     option 1
    ///     option 2
    ///
    func table1Items() -> [InvExp] {
        var exps: [InvExp] = []
        repeat {
            take(.newline)
            guard let exp = mix() else {
                fatalError(errorText("Expected expression parsing table."))
            }
            exps.append(exp)
        } while seq(.newline, .newline) == nil
        return exps
    }

    /// Captures a list of rule1-separated expressions and returns them in an
    /// array.
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
    func table2Items() -> [InvExp] {
        var exps: [InvExp] = []
        repeat {
            take(.newline)
            guard let exp = mix(multiline: true) else {
                // We need at least one mix expression in the table.
                fatalError(errorText("Expected list item parsing table2"))
            }
            exps.append(exp)

            // After the expression we need a rule1.
            if take(.rule1) == nil {
                fatalError(errorText("Expected rule1 separated list items"))
            }
        } while seq(.newline, .newline) == nil
        return exps
    }

    /// Provides basic info for error messages including the current token.
    ///
    /// - TODO: Add more info. Unwrap the optional.
    func errorText(_ msg: String) -> String {
        let token = String(describing: self.token(at: current))
        return "\(msg)\nCurrent token: \(String(describing: token))"
    }
}
