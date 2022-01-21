//
//  CoverageFormatter.swift
//
//
//  Created by Kasper Weibel Nielsen-Refs on 19/01/2022.
//

import Foundation
import XCResultKit

// MARK: - CoverageFormatter

class CoverageFormatter {
    // MARK: Lifecycle

    init(resultFile: XCResultFile, outputFormatter: XCResultFormatting, coverageTargets: [String] = []) {
        self.outputFormatter = outputFormatter
        self.codeCoverage = resultFile.getCodeCoverage()
        self.coverageTargets = codeCoverage?.targets(filteredBy: coverageTargets) ?? []
    }

    // MARK: Internal

    func createCoverageReport() -> [String] {
        var lines: [String] = []
        lines.append(
            outputFormatter.testConfiguration("Coverage report")
        )
        guard let codeCoverage = codeCoverage else {
            return lines
        }
        var executableLines: Int = 0
        var coveredLines: Int = 0
        for target in codeCoverage.targets {
            guard coverageTargets.contains(target.name) else { continue }
            executableLines += target.executableLines
            coveredLines += target.coveredLines
            lines.append(targetSummary(target: target))
            if !outputFormatter.accordionOpenTag.isEmpty {
                lines.append(
                    outputFormatter.accordionOpenTag
                )
            }
            for file in target.files {
                let covPercent = percentFormatter.unwrappedString(for: file.lineCoverage * 100)
                lines.append(
                    outputFormatter.codeCoverageFileSummary(
                        "\(file.path): \(covPercent)% (\(file.coveredLines)/\(file.executableLines))"
                    )
                )
                if !outputFormatter.accordionOpenTag.isEmpty {
                    lines.append(
                        outputFormatter.accordionOpenTag
                    )
                }
                if !outputFormatter.tableOpenTag.isEmpty {
                    lines.append(
                        outputFormatter.tableOpenTag
                    )
                }
                for function in file.functions {
                    let covPercentLine = percentFormatter.unwrappedString(for: function.lineCoverage * 100)
                    lines.append(
                        outputFormatter.codeCoverageFunctionSummary(
                            ["\(covPercentLine)%", "\(function.name):\(function.lineNumber)", "(\(function.coveredLines)/\(function.executableLines))", "\(function.executionCount) times"]
                        )
                    )
                }
                if !outputFormatter.tableCloseTag.isEmpty {
                    lines.append(
                        outputFormatter.tableCloseTag
                    )
                }
                if !outputFormatter.accordionCloseTag.isEmpty {
                    lines.append(
                        outputFormatter.accordionCloseTag
                    )
                }
            }
            if !outputFormatter.accordionCloseTag.isEmpty {
                lines.append(
                    outputFormatter.accordionCloseTag
                )
            }
        }

        // Append the total coverage below the header
        if executableLines > 0 {
            let line = totalSummary(executableLines: executableLines, coveredLines: coveredLines)
            lines.insert(line, at: 1)
        }

        let analysis = formatAnalysis(targets: codeCoverage.targets, executableLines: executableLines, coveredLines: coveredLines)

        lines.append(contentsOf: analysis)

        return lines
    }

    // MARK: Private

    private typealias AnalysisResult = (coverage: Double, lines: [String])

    private let codeCoverage: CodeCoverage?
    private let outputFormatter: XCResultFormatting
    private let coverageTargets: Set<String>

    private var percentFormatter: NumberFormatter = {
        let numFormatter = NumberFormatter()
        numFormatter.maximumFractionDigits = 1
        return numFormatter
    }()

    private func targetSummary(target: CodeCoverageTarget) -> String {
        let covPercent = percentFormatter.unwrappedString(for: target.lineCoverage * 100)
        return outputFormatter.codeCoverageTargetSummary(
            "\(target.name): \(covPercent)% (\(target.coveredLines)/\(target.executableLines))"
        )
    }

    private func totalSummary(executableLines: Int, coveredLines: Int) -> String {
        let fraction = Double(coveredLines) / Double(executableLines)
        let covPercent: String = percentFormatter.unwrappedString(for: fraction * 100)
        let line = outputFormatter.codeCoverageTargetSummary("Total coverage: \(covPercent)% (\(coveredLines)/\(executableLines))")
        return line
    }

    private func filesSummary(target: CodeCoverageTarget) -> String {
        let covPercent = percentFormatter.unwrappedString(for: target.lineCoverage * 100)
        return outputFormatter.codeCoverageTargetSummary(
            "\(target.name): \(covPercent)% (\(target.coveredLines)/\(target.executableLines))"
        )
    }

    private func formatAnalysis(targets: [CodeCoverageTarget], executableLines: Int, coveredLines: Int) -> [String] {
        var analysisResult: [AnalysisResult] = []
        for target in targets {
            guard coverageTargets.contains(target.name) else { continue }
            let result = analysis(target: target, projectExecutableLines: executableLines)
            analysisResult.append(result)
        }

        let covered = Double(coveredLines) / Double(executableLines)
        let combinedGain: Double = analysisResult.reduce(covered) { partialResult, result in
            partialResult + result.coverage
        }

        let leftover = 1 - combinedGain
        let covPercent = percentFormatter.unwrappedString(for: leftover * 100)
        let line = outputFormatter.testConfiguration("\(covPercent)% coverage gain for all other project targets")
        analysisResult.append((leftover, [line]))

        analysisResult = analysisResult.sorted {
            $0.coverage > $1.coverage
        }

        var result: [String] = []
        analysisResult.forEach { _, lines in
            lines.forEach { line in
                result.append(line)
            }
        }

        return result
    }

    private func analysis(target: CodeCoverageTarget, projectExecutableLines: Int) -> AnalysisResult {
        var lines: [String] = []
        let analysis = CoverageAnalyzer(files: target.files).analyze()
        var maxFraction: Double = 0
        for analysisLine in analysis {
            let fraction = Double(analysisLine.missedLines) / Double(projectExecutableLines)
            // Discard low value items
            guard fraction > 0.01 else { continue }
            maxFraction = max(maxFraction, fraction)
            let covPercent: String = percentFormatter.unwrappedString(for: fraction * 100)
            lines.append(
                outputFormatter.codeCoverageFileSummary(
                    "\(analysisLine.path), potential: \(covPercent)%"
                )
            )
        }
        guard lines.count > 0 else { return (0, []) }
        let covPercent: String = percentFormatter.unwrappedString(for: maxFraction * 100)
        lines.insert(
            outputFormatter.testConfiguration("\(covPercent)% project coverage gain potential for \(target.name)"),
            at: 0
        )
        return (maxFraction, lines)
    }
}

private extension CodeCoverage {
    func targets(filteredBy filter: [String]) -> Set<String> {
        let targetNames = targets.map { $0.name }
        guard !filter.isEmpty else {
            return Set(targetNames)
        }
        let filterSet = Set(filter)
        let filtered = targetNames.filter { thisTarget in
            // Clean up target.name. Split on '.' because the target.name is appended with .framework or .app
            guard let stripped = thisTarget.split(separator: ".").first else { return true }
            return filterSet.contains(String(stripped))
        }
        return Set(filtered)
    }
}
