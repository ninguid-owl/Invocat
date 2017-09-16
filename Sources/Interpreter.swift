//
//  Interpreter.swift
//  LibInvocat
//

class Interpreter {
    let parser: Parser
    let evaluator: Evaluator

    var state: InvState = [:]

    init(seed: String? = nil) {
        parser = Parser()
        evaluator = seed == nil ? Evaluator() : Evaluator(seed: seed!)
    }

    // TODO Test
    // NOTE side effects: updates state!
    private func evaluate(_ exps: [InvExp]) -> [String]? {
        let values = exps.map { (exp: InvExp) -> String? in
            let value: String?
            (self.state, value) = evaluator.eval(exp, in: self.state)
            return value
        }
        return values.flatMap({$0})
    }

    func eval(text: String) -> [String]? {
        let tokens = Lexer.tokens(from: text)
        let expressions = parser.parse(tokens: tokens)
        let values = evaluate(expressions)
        return values
    }

    func eval(file path: String) -> [String]? {
        guard let text = try? String(contentsOfFile: path) else { return nil }
        return eval(text: text)
    }
}
