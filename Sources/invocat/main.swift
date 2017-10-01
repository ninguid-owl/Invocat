//
//  main.swift
//  invocat
//
//

import Darwin
import LibInvocat


let invocat = Interpreter.init(seed: "test")
//invocat.eval(file: path)?.forEach{ print($0) }

while true {
    print("> ", terminator: "")
    guard let input = readLine() else { exit(0) }
    invocat.eval(text: input)?.forEach{ print($0) }
}
