//
//  Parser.swift
//  LibInvocat
//
//  TODO: Better errors. Throw instead of fatalError.
//  TODO: Set access levels on parser functions
//  TODO: comments must not require blank space after --
//
//

class Parser {

    private var current = 0
    private var tokens: [Token] = []

    func parse(tokens: [Token]) -> [InvExp] {
        self.tokens = tokens
        var expressions: [InvExp] = []

        stripNewlines()     // TODO: Should newlines ever be literals?

        while current < tokens.count {
            // As long as there's a token to examine, get a new expression
            // and consume all following newlines.
            guard let exp = expression() else {
                fatalError(errorText("Could not parse expression."))
            }
            expressions.append(exp)
            stripNewlines()
        }
        return expressions
    }

    func getToken(atIndex index: Int) -> Token? {
        return tokens.indices.contains(index) ? tokens[index] : nil
    }
    
    @discardableResult
    // Consume and return the current token if it matches a provided type.
    func take(_ types: TokenType...) -> Token? {
        // If the current token's type matches one of the types provided,
        // consume and return the token.
        if let token = getToken(atIndex: current), types.contains(token.type) {
            current += 1
            return token
        }
        return nil
    }

    // Return true if the current token (or the token at the specified index)
    // matches any of the provided token types.
    func peek(at index: Int? = nil, _ types: TokenType...) -> Bool {
        let index = index ?? current
        if let token = getToken(atIndex: index) {
            return types.contains(token.type)
        }
        return false
    }

    // Consume and return the next n tokens if they match the provided types.
    func seq(_ types: TokenType...) -> [Token]? {
        let last = current + types.count
        if  last > tokens.count { return nil }
        let actual = tokens[current..<last].map{ $0.type }
        if types == actual {
            return types.map{ take($0)! }
        }
        return nil
    }

    func stripNewlines() {
        while peek(.newline) { take(.newline) }
    }

    func expression() -> InvExp? {
        return definition()           ??    // name :: list
               selection()            ??    // name <- list
               evaluatingDefinition() ??    // name :! list
               evaluatingSelection()  ??    // name <! list
               mix()                        // literal|reference|draw  mix
    }
    
    func definition() -> InvExp? {
        // Definitions can use the define operator or one of the two table
        // formats.
        if let def = table1() ?? table2() {
            return def
        }
        guard let name = seq(.name, .define)?.first else {
            return nil
        }
        return InvExp.definition(name: name.lexeme, items: list())
    }
    
    func selection() -> InvExp? {
        guard let name = seq(.name, .select)?.first else {
            return nil
        }
        return InvExp.selection(name: name.lexeme, items: list())
    }
    
    func evaluatingDefinition() -> InvExp? {
        guard let name = seq(.name, .defEval)?.first else {
            return nil
        }
        return InvExp.evaluatingDefinition(name: name.lexeme, items: list())
    }
    
    func evaluatingSelection() -> InvExp? {
        guard let name = seq(.name, .selEval)?.first else {
            return nil
        }
        return InvExp.evaluatingSelection(name: name.lexeme, items: list())
    }
    
    func mix(multiline: Bool = false) -> InvExp? {
        // A mix combines adjacent permutations of references, draws,
        // and literals. If multiline is true, mixes can cover multiple lines
        // and break at a rule1.
        guard var exp1 = reference() ?? draw() ?? literal() else {
            return nil
        }
        if multiline {
            // If we're matching multiline expressions, bail when we see a
            // rule1. Otherwise, join consecutive lines with a single space.
            take(.newline)
            if peek(.rule1) { return exp1 }
            exp1 = InvExp.mix(item1: exp1, item2: InvExp.literal(literal: " "))
        }
        else if peek(.newline, .pipe) { return exp1 }
        guard let exp2 = mix(multiline: multiline) else {
            fatalError(errorText("Expected second expression in mix."))
        }
        return InvExp.mix(item1: exp1, item2: exp2)
    }

    func reference() -> InvExp? {
        // TODO: test failure on unclosed paren.
        // A reference is a name surrounded by parens: (ref name)
        guard let name = seq(.lparen, .name, .rparen)?[1] else {
            return nil
        }
        return InvExp.reference(name: name.lexeme)
    }
    
    func draw() -> InvExp? {
        // A draw is a name surrounded by braces: {ref name}
        guard let name = seq(.lbrace, .name, .rbrace)?[1] else {
            return nil
        }
        return InvExp.draw(name: name.lexeme)
    }
    
    func literal() -> InvExp? {
        // A literal is a name, number, punctuation, escape, or whitespace 
        // optionally followed by another literal.
        if !peek(.name, .number, .punct, .escape, .white) { return nil }
        
        var value: String = ""
        repeat {
            if let token = take(.name, .number, .punct, .escape, .white) {
                value = value.appending(token.lexeme)
            }
        } while peek(.name, .number, .punct, .escape, .white)
        return InvExp.literal(literal: value)
    }
    
    func list() -> [InvExp] {
        // Capture pipe-separated expressions
        // TODO: Restrict to mixes? The abstract syntax allows any expression
        // but that's probably not useful.
        var exps: [InvExp] = []
        repeat {
            take(.pipe)
            guard let exp = expression() else {
                fatalError(errorText("Expected expression parsing list."))
            }
            exps.append(exp)
        } while peek(.pipe)
        return exps
    }

    func table1() -> InvExp? {
        // A name, newline, rule1 followed by a list on consecutive lines.
        guard let name = seq(.name, .newline, .rule1)?.first else {
            return nil
        }
        return InvExp.definition(name: name.lexeme, items: table1Items())
    }

    func table2() -> InvExp? {
        // A name, newline, rule2 followed by a list on consecutive lines.
        guard let name = seq(.name, .newline, .rule2)?.first else {
            return nil
        }
        return InvExp.definition(name: name.lexeme, items: table2Items())
    }

    func table1Items() -> [InvExp] {
        // Capture newline-separated expressions. Two consecutive newlines
        // terminate the list. Once you're in a table1 the only legal sequences
        // are mix newline, or newline newline.
        // TODO: Generalize list with sepToken, endSeq, errMsg?
        //
        //  name
        //  --------
        //  option 1
        //  option 2
        //
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

    func table2Items() -> [InvExp] {
        // Capture rule1-separated expressions. Two consecutive newlines
        // terminates the list.
        //
        //  name
        //  ==========
        //  multi-line
        //  expression
        //  ----------
        //  second opt
        //  ----------
        //
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

    // Provide info for error messages including the current token.
    // TODO: More info. Unwrap optional.
    func errorText(_ msg: String) -> String {
        let token = String(describing: getToken(atIndex: current))
        return "\(msg)\nCurrent token: \(String(describing: token))"
    }
}
