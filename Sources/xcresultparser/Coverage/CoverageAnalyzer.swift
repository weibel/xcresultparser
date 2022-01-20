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

    /**
      Analyze the coverage for the files

      The returned list is sorted by the directory with the biggest number of uncovered lines. See the test case for an example
      In sequence the first items have the largest potential for coverage improvement

      - Returns: A list of CoverageAnalysisLine with a recursive sum of executableLines and coveredLines in the directories in the filessystem.
     */
    func analyze() -> [CoverageAnalysisLine] {
        let missinglines = countMissingLines()
        let tally = tallyDirectories(lines: missinglines)
        let sorted = sortByMissing(lines: tally)
        return sorted
    }

    // MARK: Private

    private let files: [CodeCoverageFile]

    /**
      Sum executableLines and coveredLines per directory

      - Returns: An Array with a CoverageAnalysisLine per directory in the files sorted by the path string
     */
    private func countMissingLines() -> [CoverageAnalysisLine] {
        var result: OrderedDictionary<URL, CoverageAnalysisLine> = [:]
        for file in files {
            let path = URL(fileURLWithPath: file.path).deletingLastPathComponent()
            let def = CoverageAnalysisLine(path: path)
            result.updateValue(forKey: path, default: def) { value in
                value.executableLines += file.executableLines
                value.coveredLines += file.coveredLines
            }
        }
        return Array(result.values)
    }

    /**
      Recursively Sum executableLines and coveredLines per directory

      - Parameter lines: An Array of CoverageAnalysisLine

      - Returns: An Array with a CoverageAnalysisLine per directory in the filesystem
     */
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

    /**
      Sort by the directory with the biggest number of uncovered lines. See the test case for an example
      When printed in sequence the top items have the largest potential for coverage improvement

      - Parameter lines: An Array of CoverageAnalysisLine

      - Returns: An Array with a CoverageAnalysisLine per directory sorted by the directory with the biggest number of uncovered lines
     */
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
            } while lhComp[idx - 1] == rhComp[idx - 1] && (idx < lhComp.count && idx < rhComp.count)
            let lookup1 = lookup[key1] ?? 0
            let lookup2 = lookup[key2] ?? 0
            if lookup1 == lookup2 {
                return key1.joined().localizedStandardCompare(key2.joined()) == .orderedDescending
            } else {
                return lookup[key1] ?? 0 > lookup[key2] ?? 0
            }
        }
        return result
    }
}
