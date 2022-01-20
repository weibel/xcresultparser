//
//  File.swift
//  
//
//  Created by Kasper Weibel Nielsen-Refs on 19/01/2022.
//

import Foundation

extension NumberFormatter {
    func unwrappedString(for input: Double?) -> String {
        return string(for: input) ?? ""
    }
}
