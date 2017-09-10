//
//  Parser.swift
//  LibInvocat
//
//  TODO: Better errors.
//
//

class Parser {
    var tokens: [Token]
    
    // TODO: Use indices or range instead
    var prev: Token?
    var curr: Token?
    var next: Token?
    var last: Token?
    
    init(tokens: [Token]) {
        // TODO: No need to mutate the tokens array. Use indices instead.
        self.tokens = Array(tokens.reversed())  // Now it's a stack
        curr = self.tokens.popLast()            // Do these with a range instead?
        next = self.tokens.popLast()
        last = self.tokens.popLast()            // NOTE: needed for tables
    }
    
    func parse() -> [InvExp] {
        var expressions: [InvExp] = []
        
        while peek(.newline) { take(.newline) } // Strip leading newlines
        while curr != nil {
            // As long as there's a token to examine, get a new expression
            // and consume all following newlines.
            guard let exp = expression() else {
                fatalError("Expected expression: \(String(describing: curr!))")
            }
            expressions.append(exp)
            
            // TODO: Should newlines ever be literals?
            while peek(.newline) { take(.newline) }
            
        }
        return expressions
    }
    
    @discardableResult
    func take(_ types: TokenType...) -> Token? {
        // If the current token's type matches one of the types
        // provided, consume and return the token.
        if let t = curr?.type, types.contains(t) {
            (prev, curr, next, last) = (curr, next, last, tokens.popLast())
            return prev
        }
        return nil
    }
    
    // TODO: Should take and peek and next accept arrays?
    // That way we can do multi token look-ahead which is
    // needed for the tables.
    func peek(_ types: TokenType...) -> Bool {
        if let t = curr?.type {
            return types.contains(t)
        }
        return false
    }
    
    func next(_ types: TokenType...) -> Bool {
        if let t = next?.type {
            return types.contains(t)
        }
        return false
    }
    
    func expression() -> InvExp? {
        return definition()           ??    // name :: list
               selection()            ??    // name <- list
               evaluatingDefinition() ??    // name :! list
               evaluatingSelection()  ??    // name <! list
               mix()                        // literal|reference|draw  mix
    }
    
    func definition() -> InvExp? {
        if next(.define), let name = take(.name) {
            take(.define)
            return InvExp.definition(name: name.lexeme, items: list())
        }
        return nil
    }
    
    func selection() -> InvExp? {
        if next(.select), let name = take(.name) {
            take(.select)
            return InvExp.selection(name: name.lexeme, items: list())
        }
        return nil
    }
    
    func evaluatingDefinition() -> InvExp? {
        if next(.defEval), let name = take(.name) {
            take(.defEval)
            return InvExp.evaluatingDefinition(name: name.lexeme, items: list())
        }
        return nil
    }
    
    func evaluatingSelection() -> InvExp? {
        if next(.selEval), let name = take(.name) {
            take(.selEval)
            return InvExp.evaluatingSelection(name: name.lexeme, items: list())
        }
        return nil
    }
    
    func mix() -> InvExp? {
        // A mix combines adjacent permutations of references,
        // draws, and literals.
        if let exp1 = reference() ?? draw() ?? literal() {
            if peek(.newline, .pipe) { return exp1 }
            
            guard let exp2 = mix() else {
                fatalError("Expected second expression in mix \(curr!)")
            }
            return InvExp.mix(item1: exp1, item2: exp2)
        }
        return nil
    }
    
    func reference() -> InvExp? {
        // A reference is a name surrounded by parens: (ref name)
        if let _ = take(.lparen), let name = take(.name), let _ = take(.rparen) {
            return InvExp.reference(name: name.lexeme)
        }
        return nil
    }
    
    func draw() -> InvExp? {
        // A draw is a name surrounded by braces: {ref name}
        if let _ = take(.lbrace), let name = take(.name), let _ = take(.rbrace) {
            return InvExp.draw(name: name.lexeme)
        }
        return nil
    }
    
    func literal() -> InvExp? {
        // A literal is a name, punctuation, escape, or whitespace
        // optionally followed by another literal.
        // TODO: Should all punctuation be allowed in names?
        
        if !peek(.name, .punct, .escape, .white) { return nil }
        
        var value: String = ""
        repeat {
            if let token = take(.name, .punct, .escape, .white) {
                value = value.appending(token.lexeme)
            }
            // If there's a split, consume it and the following newline.
            // TODO: Consume the following newline in the lexer?
            if let _ = take(.split) { take(.newline) }
        } while peek(.name, .punct, .escape)
        return InvExp.literal(literal: value)
    }
    
    func list() -> [InvExp] {
        // Capture pipe-separated expressions
        var exps: [InvExp] = []
        repeat {
            take(.pipe)
            guard let exp = expression() else {
                fatalError("Expected expression parsing list: \(curr!)")
            }
            exps.append(exp)
        } while peek(.pipe)
        return exps
    }
}
