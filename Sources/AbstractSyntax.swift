import GameKit


typealias InvState = [String: [InvExp]]

// Abstract syntax

// We follow the functional idea that everything is an expression.
// This certainly cleans up the eval code, but the grammar then allows for
// things like recursive definitions. The concrete syntax should not allow
// that, however.
// NOTE The .mix case could possibly be [InvExp] for efficiency.

// TODO describe the operators ::, :!, <-, <!

// Other possible expressions:
//   * Merge two lists
//   * Append to a list
//   * Duplicate a list
//     ...

indirect enum InvExp {
    case definition           (name: String, items: [InvExp]) // ::
    case selection            (name: String, items: [InvExp]) // <-
    case evaluatingDefinition (name: String, items: [InvExp]) // :!
    case evaluatingSelection  (name: String, items: [InvExp]) // <!
    case reference            (name: String)                  // ()
    case draw                 (name: String)                  // {}
    case literal              (literal: String)
    case mix                  (item1: InvExp, item2: InvExp)
}

// Eval

// NOTE Functional approach: eval takes (expression, state) and returns (state, value).
// This may eventually need to be optimized because it is definitely not efficient.
// Although we could move the return outside the switch, that is even
// less efficient in the cases where state doesn't have to be copied.
func eval(_ exp: InvExp?, in state: InvState) -> (state: InvState, value: String?) {
    guard exp != nil else { return (state, nil) }
    switch exp! {
    case let .definition(name, items):
        var newState = state
        newState[name] = items
        return (newState, nil)
    case let .selection(name, items):
        var newState = state
        if let item = items.randomElement() {
            newState[name] = [item]
        }
        return (newState, nil)
    case let .evaluatingDefinition(name, items):
        var newState = state
        var newItems: [InvExp] = []
        for item in items {
            let value: String?
            (newState, value) = eval(item, in: newState)
            if value != nil {
                newItems.append(.literal(literal: value!))
            }
        }
        newState[name] = newItems
        return (newState, nil)
    case let .evaluatingSelection(name, items):
        var newState = state
        if let item = items.randomElement() {
            let value: String?
            (newState, value) = eval(item, in: newState)
            if value != nil {
                newState[name] = [.literal(literal: value!)]
            }
        }
        return (newState, nil)
    case let .reference(name):
        var newState = state
        let value: String?
        (newState, value) = eval(state[name]?.randomElement(), in: newState)
        return (newState, value)
    case let .draw(name):
        if let item = state[name]?.randomElement() {
            var newState = state
            let remainingItems = newState[name]?.filter({$0 != item})
            newState[name] = (remainingItems?.isEmpty ?? true) ? nil : remainingItems
            let value: String?
            (newState, value) = eval(item, in: newState)
            return (newState, value)
        }
        return (state, nil)
    case let .literal(literal):
        return (state, literal)
    case let .mix(item1, item2):
        var newState = state
        let lhs: String?, rhs: String?
        (newState, lhs) = eval(item1, in: newState)
        (newState, rhs) = eval(item2, in: newState)
        let value = "\(lhs ?? "")\(rhs ?? "")"
        return (newState, value)
    }
}

// Extensions & operators

// Return random element from Array
let seedString = "Atrament" // TODO for testing
let seedData = Data(seedString.utf8)
let randomSource = GKARC4RandomSource(seed: seedData)
extension Array {
    func randomElement() -> Element? {
        if isEmpty { return nil }
        let distribution = GKRandomDistribution(randomSource: randomSource, lowestValue: 0, highestValue: count-1)
        return self[distribution.nextInt()]
    }
}

// InvExp equatable
extension InvExp: Equatable {
    static func == (lhs: InvExp, rhs: InvExp) -> Bool {
        return lhs.description == rhs.description
    }
}

// Operators
prefix operator ^   // literal
prefix operator *   // reference
prefix operator %   // draw
infix operator *    // definition
infix operator ~    // selection
infix operator *!   // evaluatingDefinition
infix operator ~!   // evaluatingSelection

// Define operators
// ... literal, reference, draw, definition, selection, 
// evaluatingDefinition, evaluatingSelection
extension String {
    static prefix func ^ (right: String) -> InvExp { return InvExp.literal(literal: right) }
    static prefix func * (right: String) -> InvExp { return InvExp.reference(name: right) }
    static prefix func % (right: String) -> InvExp { return InvExp.draw(name: right) }
    static func * (left: String, right: [InvExp]) -> InvExp {
        return InvExp.definition(name: left, items: right)
    }
    static func ~ (left: String, right: [InvExp]) -> InvExp {
        return InvExp.selection(name: left, items: right)
    }
    static func *! (left: String, right: [InvExp]) -> InvExp {
        return InvExp.evaluatingDefinition(name: left, items: right)
    }
    static func ~! (left: String, right: [InvExp]) -> InvExp {
        return InvExp.evaluatingSelection(name: left, items: right)
    }
}
// ... mix
extension InvExp {
    static func + (left: InvExp, right: InvExp) -> InvExp {
        return InvExp.mix(item1: left, item2: right)
    }
}

// InvExp String representation
extension InvExp: CustomStringConvertible {
    var description: String {
        switch self {
        case let .definition(name, items):
            return "\(name) :: \(items.flatMap({$0.description}).joined(separator: " | "))"
        case let .selection(name, items):
            return "\(name) <- \(items.flatMap({$0.description}).joined(separator: " | "))"
        case let .evaluatingDefinition(name, items):
            return "\(name) :! \(items.flatMap({$0.description}).joined(separator: " | "))"
        case let .evaluatingSelection(name, items):
            return "\(name) <! \(items.flatMap({$0.description}).joined(separator: " | "))"
        case let .reference(name):
            return "(\(name))"
        case let .draw(name):
            return "{\(name)}"
        case let .literal(literal):
            return "\(literal)"
        case let .mix(item1, item2):
            return "\(item1)\(item2)"
        }
    }
}

// InvExp.literal expressible as String literal
extension InvExp: ExpressibleByStringLiteral,
                  ExpressibleByExtendedGraphemeClusterLiteral,
                  ExpressibleByUnicodeScalarLiteral {
    init(stringLiteral value: String) {
        self = InvExp.literal(literal: value)
    }
    init(extendedGraphemeClusterLiteral value: String) {
        self = InvExp.literal(literal: value)
    }
    init(unicodeScalarLiteral value: String) {
        self = InvExp.literal(literal: value)
    }
}

// This is rather a hack for formatting the output of an InvState
extension Dictionary where Value: Sequence {
    var text: String {
        var result = ""
        for (name, items) in self {
            result += "  \(name): \(items.flatMap({"\($0)"}).joined(separator: " | "))\n"
        }
        return "........................................................\n" +
               result +
               "........................................................"
    }
}
