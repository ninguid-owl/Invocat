//
//  Interpreter.swift
//  LibInvocat
//

/// An interpreter for the Invocat language.
public class Interpreter {
    let parser: Parser
    let evaluator: Evaluator

    /// The interpreter keeps the state against which it evaluates expressions.
    var state: InvState = [:]

    /// Initializes an Interpreter with a given random seed.
    public init(seed: String? = nil) {
        parser = Parser()
        evaluator = seed == nil ? Evaluator() : Evaluator(seed: seed!)
    }

    /// Evaluates a list of expressions in the interpreter's current state, 
    /// updating that state each time.
    ///
    /// Note: This function has the side effect of updating state.
    private func evaluate(_ exps: [InvExp]) -> [String]? {
        let values = exps.flatMap { (exp: InvExp) -> String? in
            let value: String?
            (self.state, value) = evaluator.eval(exp, in: self.state)
            return value
        }
        return values.isEmpty ? nil : values
    }

    /// Interprets a String of Invocat source text and returns an optional array
    /// of any resulting values.
    ///
    /// The text is tokenized, parsed, and then evaluated against the
    /// interpreter's state.
    ///
    /// - Parameter text: A String of Invocat source.
    public func eval(text: String) -> [String]? {
        let tokens = Lexer.tokens(from: text)
        let expressions = parser.parse(tokens: tokens)
        let values = evaluate(expressions)
        return values
    }

    /// Interprets a file of Invocat source text and returns an optional array
    /// of any resulting values.
    ///
    /// The text is tokenized, parsed, and then evaluated against the
    /// interpreter's state.
    ///
    /// - Parameter file: A path to an Invocat source file.
    public func eval(file path: String) -> [String]? {
        guard let text = try? String(contentsOfFile: path) else { return nil }
        return eval(text: text)
    }

    /// Returns all of the names in the state dictionary.
    public func names() -> [String]? {
        return Array(state.keys)
    }
}
