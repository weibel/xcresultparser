//
//  File.swift
//
//
//  Created by Kasper Weibel Nielsen-Refs on 19/01/2022.
//

import Foundation
import XCResultKit
import XCTest

@testable import Xcresultparser

final class CoverageAnalyzerTests: XCTestCase {
    var files: [CodeCoverageFile] {
        var result: [CodeCoverageFile] = []
        var file = CodeCoverageFile(coveredLines: 10, lineCoverage: 1, path: "/a/c/x.swift", name: "", executableLines: 200, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 99, lineCoverage: 1, path: "/a/b/e/g/y.swift", name: "", executableLines: 100, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 5, lineCoverage: 1, path: "/a/b/d/e/x.swift", name: "", executableLines: 20, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 5, lineCoverage: 1, path: "/a/c/y.swift", name: "", executableLines: 20, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 10, lineCoverage: 1, path: "/a/b/x.swift", name: "", executableLines: 20, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 5, lineCoverage: 1, path: "/a/b/y.swift", name: "", executableLines: 20, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 5, lineCoverage: 1, path: "/a/b/e/f/y.swift", name: "", executableLines: 100, functions: [])
        result.append(file)
        file = CodeCoverageFile(coveredLines: 5, lineCoverage: 1, path: "/a/a/x.swift", name: "", executableLines: 210, functions: [])
        result.append(file)
        return result
    }

    func testCoverageAnalyzer() throws {
        let analyzer = CoverageAnalyzer(files: files)
        let result = analyzer.analyze()
        let expect = """
[["file:///": 546], ["file:///a/": 546], ["file:///a/a/": 205], ["file:///a/c/": 205], ["file:///a/b/": 136], ["file:///a/b/e/": 96], ["file:///a/b/e/f/": 95], ["file:///a/b/e/g/": 1], ["file:///a/b/d/": 15], ["file:///a/b/d/e/": 15]]
"""
        XCTAssertEqual(expect, result.map { ["\($0.path.absoluteString)": $0.missedLines] }.description)
    }
}
