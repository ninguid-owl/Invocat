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

class Evaluator {
    let randomSource: GKRandomSource
    private var distributions: [Int: GKRandomDistribution] = [:] // Cache

    init() {
        let seed = "Today the furnace opens its mouth"
        let seedData = Data(seed.utf8)
        randomSource = GKARC4RandomSource(seed: seedData)
    }

    init(seed: String) {
        let seed = seed
        let seedData = Data(seed.utf8)
        randomSource = GKARC4RandomSource(seed: seedData)
    }

    // Return random element from Array
    func randomElement<Element>(_ array: [Element]?) -> Element? {
        guard let array = array else { return nil }
        if array.isEmpty { return nil }
        let distribution = getDistributionFrom0To(highestValue: array.count-1)
        return array[distribution.nextInt()]
    }

    // Return a distribution from 0 to highestValue using randomSource.
    // The evaluator caches the distributions rather than regenerate them
    // for each request.
    func getDistributionFrom0To(highestValue: Int) -> GKRandomDistribution {
        if let distribution = self.distributions[highestValue] {
            return distribution
        }
        let distribution = GKRandomDistribution(randomSource: randomSource,
                                                lowestValue: 0,
                                                highestValue: highestValue)
        self.distributions[highestValue] = distribution
        return distribution
    }

    // NOTE Functional approach: eval takes (expression, state) and
    // returns (state, value). This may eventually need to be optimized because
    // it is definitely not efficient.
    func eval(_ exp: InvExp?, in state: InvState) -> (state: InvState,
                                                      value: String?) {
        guard let exp = exp else { return (state, nil) }
        var newState = state
        var value: String? = nil
        switch exp {
        case let .definition(name, items):
            newState[name] = items
        case let .selection(name, items):
            if let item = randomElement(items) {
                newState[name] = [item]
            }
        case let .evaluatingDefinition(name, items):
            var newItems: [InvExp] = []
            for item in items {
                let itemValue: String?
                (newState, itemValue) = eval(item, in: newState)
                if let itemValue = itemValue {
                    newItems.append(.literal(literal: itemValue))
                }
            }
            newState[name] = newItems
        case let .evaluatingSelection(name, items):
            if let item = randomElement(items) {
                let itemValue: String?
                (newState, itemValue) = eval(item, in: newState)
                if let itemValue = itemValue {
                    newState[name] = [.literal(literal: itemValue)]
                }
            }
        case let .reference(name):
            (newState, value) = eval(randomElement(state[name]), in: newState)
        case let .draw(name):
            if let item = randomElement(state[name]) {
                let remainingItems = newState[name]?.filter({$0 != item})
                newState[name] = (remainingItems?.isEmpty ?? true) ?
                    nil : remainingItems
                (newState, value) = eval(item, in: newState)
            }
        case let .literal(literal):
            value = literal
        case let .mix(item1, item2):
            let lhs: String?, rhs: String?
            (newState, lhs) = eval(item1, in: newState)
            (newState, rhs) = eval(item2, in: newState)
            value = "\(lhs ?? "")\(rhs ?? "")"
        }
        return (newState, value)
    }
}

// Extensions & operators

// Operators
// TODO move to test??
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

// InvExp equatable
extension InvExp: Equatable {
    static func == (lhs: InvExp, rhs: InvExp) -> Bool {
        return lhs.description == rhs.description
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
