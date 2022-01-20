//
//  CoverageAnalyzer.swift
//
//
//  Created by Kasper Weibel Nielsen-Refs on 19/01/2022.
//

import Collections
import Foundation
import XCResultKit

// MARK: - CoverageAnalysisLine

struct CoverageAnalysisLine {
    let path: URL
    var executableLines: Int = 0
    var coveredLines: Int = 0

    var coverage: Double {
        Double(coveredLines) / Double(executableLines)
    }

    var missedLines: Int {
        executableLines - coveredLines
    }
}

// MARK: - CoverageAnalyzer

class CoverageAnalyzer {
    // MARK: Lifecycle

    init(files: [CodeCoverageFile]) {
        self.files = files
    }

    // MARK: Internal

    func analyze() -> [CoverageAnalysisLine] {
        let missinglines = countMissingLines()
        let tally = tallyDirectories(lines: missinglines)
        let sorted = sortByMissing(lines: tally)
        return sorted
    }

    // MARK: Private

    private let files: [CodeCoverageFile]

    private func countMissingLines() -> [CoverageAnalysisLine] {
        var result: OrderedDictionary<URL, CoverageAnalysisLine> = [:]
        let sortedFiles = files.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
        for file in sortedFiles {
            let path = URL(fileURLWithPath: file.path).deletingLastPathComponent()
            let def = CoverageAnalysisLine(path: path)
            result.updateValue(forKey: path, default: def) { value in
                value.executableLines += file.executableLines
                value.coveredLines += file.coveredLines
            }
        }
        return Array(result.values)
    }

    private func tallyDirectories(lines: [CoverageAnalysisLine]) -> [CoverageAnalysisLine] {
        var result: OrderedDictionary<[String], CoverageAnalysisLine> = [:]
        for line in lines {
            var key: [String] = []
            line.path.pathComponents.forEach { pathElement in
                key.append(pathElement)
                let keyString = key.joined(separator: "/").replacingOccurrences(of: "//", with: "/")
                let path = URL(fileURLWithPath: keyString, isDirectory: true).standardizedFileURL
                let def = CoverageAnalysisLine(path: path)
                result.updateValue(forKey: key, default: def) { value in
                    value.executableLines += line.executableLines
                    value.coveredLines += line.coveredLines
                }
            }
        }
        return Array(result.values)
    }

    private func sortByMissing(lines: [CoverageAnalysisLine]) -> [CoverageAnalysisLine] {
        var result: [CoverageAnalysisLine] = []
        let lookup: [[String]: Int] = lines.reduce(into: [[String]: Int]()) {
            $0[$1.path.pathComponents] = $1.missedLines
        }
        result = lines.sorted { lhs, rhs in
            let lhComp = lhs.path.pathComponents
            let rhComp = rhs.path.pathComponents
            var key1: [String] = []
            var key2: [String] = []
            var idx = 0
            repeat {
                key1.append(lhComp[idx])
                key2.append(rhComp[idx])
                idx += 1
            } while lhComp[idx - 1] == lhComp[idx - 1] && (idx < lhComp.count && idx < rhComp.count)
            return lookup[key1] ?? 0 > lookup[key2] ?? 0
        }
        return result
    }
}
