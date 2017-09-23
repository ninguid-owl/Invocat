//
//  AbstractSyntax.swift
//  LibInvocat
//
//  TODO: Describe the operators ::, :!, <-, <!
//
//  TODO: Other possible expressions:
//   * Merge two lists
//   * Append to a list
//   * Duplicate a list
//     ...

import GameKit



// Syntax, state, & semantics

/// An Invocat state: a mapping of names to expressions.
typealias InvState = [String: [InvExp]]

/// Abstract syntax.
///
/// This follows the functional idea that everything is an expression.
/// This certainly cleans up the eval code, but the grammar then allows for
/// things like recursive definitions. The concrete syntax should not allow
/// that, however.
///
/// NOTE: The .mix case could possibly be [InvExp] for efficiency.
indirect enum InvExp {
    case definition           (String, [InvExp]) // (name, items) // ::
    case selection            (String, [InvExp]) // (name, items) // <-
    case evaluatingDefinition (String, [InvExp]) // (name, items) // :!
    case evaluatingSelection  (String, [InvExp]) // (name, items) // <!
    case reference            (InvExp)           // (name!)       // ()
    case draw                 (InvExp)           // (name!)       // {}
    case literal              (String)           // (literal)
    case mix                  (InvExp, InvExp)   // (item1, item2)
}

/// An evaluator for the Invocat language.
class Evaluator {
    /// Invocat semantics require random selection.
    let randomSource: GKRandomSource
    private var distributions: [Int: GKRandomDistribution] = [:] // Cache

    /// Initializes an Evaluator with a given random seed.
    init(seed: String = "Today the furnace opens its mouth") {
        let seedData = Data(seed.utf8)
        randomSource = GKARC4RandomSource(seed: seedData)
    }

    /// Returns a random element from Array.
    private func randomElement<Element>(_ array: [Element]?) -> Element? {
        guard let array = array else { return nil }
        if array.isEmpty { return nil }
        let distribution = indicesDistribution(over: array.count)
        return array[distribution.nextInt()]
    }

    /// Return a distribution over the indices of an Array containing `count`
    /// elements using `self.randomSource`.
    ///
    /// The evaluator caches these distributions rather than regenerate them
    /// for each request.
    private func indicesDistribution(over count: Int) -> GKRandomDistribution {
        if let distribution = self.distributions[count] { return distribution }
        let distribution = GKRandomDistribution(randomSource: randomSource,
                                                lowestValue: 0,
                                                highestValue: count-1)
        self.distributions[count] = distribution
        return distribution
    }

    /// Evaluates an expression in a state, returning a new state and a value.
    ///
    /// Functional approach: eval (expression, state) -> (state, value).
    /// This may eventually need to be optimized because it is not efficient.
    func eval(_ exp: InvExp?, in state: InvState) -> (state: InvState, value: String?) {
        guard let exp = exp else { return (state, nil) }
        var newState = state
        var value: String? = nil
        switch exp {
        case let .definition(name, items):
            newState[name] = items
        case let .selection(name, items):
            if let item = randomElement(items) { newState[name] = [item] }
        case let .evaluatingDefinition(name, items):
            var newItems: [InvExp] = []
            for item in items {
                let itemValue: String?
                (newState, itemValue) = eval(item, in: newState)
                if let itemValue = itemValue {
                    newItems.append(.literal(itemValue))
                }
            }
            newState[name] = newItems
        case let .evaluatingSelection(name, items):
            if let item = randomElement(items) {
                let itemValue: String?
                (newState, itemValue) = eval(item, in: newState)
                if let itemValue = itemValue {
                    newState[name] = [.literal(itemValue)]
                }
            }
        case let .reference(nameExp):
            let (_, name) = eval(nameExp, in: newState)
            if let name = name {
                (newState, value) = eval(randomElement(state[name]), in: newState)
            }
        case let .draw(nameExp):
            let (_, name) = eval(nameExp, in: newState)
            if let name = name, let item = randomElement(state[name]) {
                let remainingItems = newState[name]?.filter({$0 != item})
                newState[name] = (remainingItems?.isEmpty ?? true) ? nil : remainingItems
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
// TODO: remove?
extension String {
    static prefix func ^ (right: String) -> InvExp {
        return InvExp.literal(right)        
    }
    static prefix func * (right: String) -> InvExp {
        return InvExp.reference(InvExp.literal(right))
    }
    static prefix func % (right: String) -> InvExp {
        return InvExp.draw(InvExp.literal(right))
    }
    static func * (left: String, right: [InvExp]) -> InvExp {
        return InvExp.definition(left, right)
    }
    static func ~ (left: String, right: [InvExp]) -> InvExp {
        return InvExp.selection(left, right)
    }
    static func *! (left: String, right: [InvExp]) -> InvExp {
        return InvExp.evaluatingDefinition(left, right)
    }
    static func ~! (left: String, right: [InvExp]) -> InvExp {
        return InvExp.evaluatingSelection(left, right)
    }
}
// ... mix
extension InvExp {
    static func + (left: InvExp, right: InvExp) -> InvExp {
        return InvExp.mix(left, right)
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

    var debugDescription: String {
        switch self {
        case let .definition(name, items):
            let items = items.flatMap({$0.debugDescription}).joined(separator: " | ")
            return "def(\(name) :: \(items))"
        case let .selection(name, items):
            let items = items.flatMap({$0.debugDescription}).joined(separator: " | ")
            return "sel(\(name) <- \(items))"
        case let .evaluatingDefinition(name, items):
            let items = items.flatMap({$0.debugDescription}).joined(separator: " | ")
            return "def!(\(name) :! \(items))"
        case let .evaluatingSelection(name, items):
            let items = items.flatMap({$0.debugDescription}).joined(separator: " | ")
            return "sel!(\(name) <! \(items))"
        case let .reference(name):
            return "ref(\(name.debugDescription))"
        case let .draw(name):
            return "draw(\(name.debugDescription))"
        case let .literal(literal):
            return "lit(\(literal))"
        case let .mix(item1, item2):
            return "mix(\(item1.debugDescription), \(item2.debugDescription))"
        }
    }
}

// InvExp.literal expressible as String literal
extension InvExp: ExpressibleByStringLiteral,
                  ExpressibleByExtendedGraphemeClusterLiteral,
                  ExpressibleByUnicodeScalarLiteral {
    init(stringLiteral value: String) {
        self = InvExp.literal(value)
    }
    init(extendedGraphemeClusterLiteral value: String) {
        self = InvExp.literal(value)
    }
    init(unicodeScalarLiteral value: String) {
        self = InvExp.literal(value)
    }
}

// This is rather a hack for formatting the output of an InvState
extension Dictionary where Value: Sequence {
    var text: String {
        var result = ""
        for (name, items) in self {
            // Count unique items; the count is the weight.
            var counts: [String: Int] = [:]
            for key in items.map({"\($0)"}) {
                counts[key] = (counts[key] ?? 0) + 1
            }
            let weightedItemList = counts.flatMap({
                // Only show weights for weight > 1.
                let weight = $0.value > 1 ? " *\($0.value)" : ""
                return "\($0.key)\(weight)"
            }).joined(separator: " | ")
            result += "  \(name): \(weightedItemList)\n"
        }
        return "........................................................\n" +
               result +
               "........................................................"
    }
}
