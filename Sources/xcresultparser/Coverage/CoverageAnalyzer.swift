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
                var def: CoverageAnalysisLine?
                key.append(pathElement)
                if result[key] == nil {
                    let pathString = key.joined(separator: "/")
                    let path = URL(fileURLWithPath: pathString, isDirectory: true).standardizedFileURL
                    def = CoverageAnalysisLine(path: path)
                }
                result.updateValue(forKey: key, default: def ?? line) { value in
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
            var lhKey: [String] = []
            var rhKey: [String] = []
            var idx = 0
            repeat {
                lhKey.append(lhComp[idx])
                rhKey.append(rhComp[idx])
                idx += 1
            } while lhComp[idx - 1] == rhComp[idx - 1] && (idx < lhComp.count && idx < rhComp.count)
            let lhLookup = lookup[lhKey] ?? 0
            let rhLookup = lookup[rhKey] ?? 0
            if lhLookup == rhLookup {
                // If the two lookups have an equal number of missedLines use string compare
                return lhKey.joined().localizedStandardCompare(rhKey.joined()) == .orderedDescending
            } else {
                return lhLookup > rhLookup
            }
        }
        return result
    }
}
