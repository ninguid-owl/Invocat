//
//  Invocat.swift
//  invocat
//
//

import Darwin
import LibInvocat

/// A command-line utility for executing Invocat files.
class Invocat {
    let usage = """
        usage: invocat [-s value] [-i] [file ...]

        -s value
            Set the randomization seed value.

        -i, --interactive
            Open an interactive shell.
        """

    var seed: String = "A flickering lamp"
    var interactive: Bool = false
    var files: [String] = []
    let invocat: Interpreter

    init(_ args: [String] = CommandLine.arguments) {
        var args = args[1...]   // The first arg is the name of the program

        if args.contains("--help") {
            print(usage)
            exit(0)
        }

        // Get the seed value if any
        if let idx = args.index(of: "-s") {
            if idx+1 < args.count {
                seed = args.remove(at: idx+1)
                args.remove(at: idx)
            }
            else { exit(1) }
        }

        // Get interactive flag
        for flag in ["-i", "--interactive"] {
            if let idx = args.index(of: flag) {
                interactive = true
                args.remove(at: idx)
            }
        }

        // Treat the remainder of the args as files
        files = Array(args)
        if files.count == 0 { interactive = true }

        // Initialize the Invocat interpreter
        invocat = Interpreter.init(seed: seed)
    }

    /// Run the utility.
    ///
    /// Reads and interprets all files given as arguments. If the `interactive`
    /// flag is set, opens an interactive prompt. At the moment this will just
    /// collects input until EOF and then evaluate it.
    func run() {
        // Evaluate all file arguments updating the interpreter's state
        for file in files {
            invocat.eval(file: file)?.forEach{ print($0) }
        }

        // TODO: Consider special commands and operators.
        // TODO: Consider progressive evaluation.
        // Collect input until EOF, then evaluate it and print the results.
        var text: [String] = []
        while interactive {
            guard let input = readLine() else { break }

            switch input {
            case "??names":
                invocat.names()?.forEach{ print($0) }
            case "??state":
                print("TODO: Show interpreter state")
            default:
                if input.hasPrefix("?") {
                    print("TODO: Show state for entry")
                }
                else {
                    text.append(input)
                }
            }
        }
        invocat.eval(text: text.joined(separator: "\n"))?.forEach{ print($0) }
    }
}
