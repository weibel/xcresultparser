//
//  XCResultFormatter.swift
//  xcresultkitten
//
//  Created by Alex da Franca on 31.05.21.
//

import Foundation
import XCResultKit

public struct XCResultFormatter {
    
    // MARK: - Properties
    
    private let resultFile: XCResultFile
    private let invocationRecord: ActionsInvocationRecord
    private let outputFormatter: XCResultFormatting
    private let coverageTargets: [String]
    
    private var numFormatter: NumberFormatter = {
        let numFormatter = NumberFormatter()
        numFormatter.maximumFractionDigits = 4
        return numFormatter
    }()
    
    private var percentFormatter: NumberFormatter = {
        let numFormatter = NumberFormatter()
        numFormatter.maximumFractionDigits = 1
        return numFormatter
    }()
    
    private var coverageFormatter: CoverageFormatter {
        return CoverageFormatter(resultFile: resultFile, outputFormatter: outputFormatter, coverageTargets: coverageTargets)
    }
    
    // MARK: - Initializer
    
    public init?(with url: URL,
          formatter: XCResultFormatting,
          coverageTargets: [String] = []
    ) {
        resultFile = XCResultFile(url: url)
        guard let record = resultFile.getInvocationRecord() else {
            return nil
        }
        invocationRecord = record
        outputFormatter = formatter
        self.coverageTargets = coverageTargets
        
        //if let logsId = invocationRecord?.actions.last?.actionResult.logRef?.id {
        //    let testLogs = resultFile.getLogs(id: logsId)
        //}
        //
        //        let testSummary = resultFile.getActionTestSummary(id: "xxx")
        
        //let payload = resultFile.getPayload(id: "123")
        //let exportedPath = resultFile.exportPayload(id: "123")
    }
    
    // MARK: - Public API
    
    public var summary: String {
        return createSummary().joined(separator: "\n")
    }
    public var testDetails: String {
        return createTestDetailsString().joined(separator: "\n")
    }
    public var divider: String {
        return outputFormatter.divider
    }
    public func documentPrefix(title: String) -> String {
        return outputFormatter.documentPrefix(title: title)
    }
    public var documentSuffix: String {
        return outputFormatter.documentSuffix
    }
    public var coverageDetails: String {
        return coverageFormatter.createCoverageReport().joined(separator: "\n")
    }
    
    // MARK: - Private API
    
    private func createSummary() -> [String] {
        let metrics = invocationRecord.metrics
        
        let analyzerWarningCount = metrics.analyzerWarningCount ?? 0
        let errorCount = metrics.errorCount ?? 0
        let testsCount = metrics.testsCount ?? 0
        let testsFailedCount = metrics.testsFailedCount ?? 0
        let warningCount = metrics.warningCount ?? 0
        let testsSkippedCount = metrics.testsSkippedCount ?? 0
        
        var lines = [String]()
        
        lines.append(
            outputFormatter.testConfiguration("Summary")
        )
        lines.append(
            outputFormatter.resultSummaryLine("Number of errors = \(errorCount)", failed: errorCount != 0)
        )
        lines.append(
            outputFormatter.resultSummaryLineWarning("Number of warnings = \(warningCount)", hasWarnings: warningCount != 0)
        )
        lines.append(
            outputFormatter.resultSummaryLineWarning("Number of analyzer warnings = \(analyzerWarningCount)", hasWarnings: analyzerWarningCount != 0)
        )
        lines.append(
            outputFormatter.resultSummaryLine("Number of tests = \(testsCount)", failed: false)
        )
        lines.append(
            outputFormatter.resultSummaryLine("Number of failed tests = \(testsFailedCount)", failed: testsFailedCount != 0)
        )
        lines.append(
            outputFormatter.resultSummaryLine("Number of skipped tests = \(testsSkippedCount)", failed: testsSkippedCount != 0)
        )
        return lines
    }
    
    private func createTestDetailsString() -> [String] {
        var lines = [String]()
        let testAction = invocationRecord.actions.first { $0.schemeCommandName == "Test" }
        guard let testsId = testAction?.actionResult.testsRef?.id,
              let testPlanRun = resultFile.getTestPlanRunSummaries(id: testsId) else {
            return lines
        }
        let testPlanRunSummaries = testPlanRun.summaries
        let failureSummaries = invocationRecord.issues.testFailureSummaries
        
        for thisSummary in testPlanRunSummaries {
            lines.append(
                outputFormatter.testConfiguration(thisSummary.name)
            )
            for thisTestableSummary in thisSummary.testableSummaries {
                for thisTest in thisTestableSummary.tests {
                    lines = lines + createTestSummaryInfo(thisTest, level: 0, failureSummaries: failureSummaries)
                }
                lines.append(
                    outputFormatter.divider
                )
            }
        }
        return lines
    }
    
    private func createTestSummaryInfo(_ group: ActionTestSummaryGroup, level: Int, failureSummaries: [TestFailureIssueSummary]) -> [String] {
        var lines = [String]()
        let header = "\(group.nameString) (\(numFormatter.unwrappedString(for: group.duration)))"
        
        switch level {
        case 0:
            break
        case 1:
            lines.append(
                outputFormatter.testTarget(header, failed: group.hasFailedTests)
            )
        case 2:
            lines.append(
                outputFormatter.testClass(header, failed: group.hasFailedTests)
            )
        default:
            lines.append(
                outputFormatter.testClass(header, failed: group.hasFailedTests)
            )
        }
        for subGroup in group.subtestGroups {
            lines = lines + createTestSummaryInfo(subGroup, level: level + 1, failureSummaries: failureSummaries)
        }
        if !outputFormatter.accordionOpenTag.isEmpty {
            lines.append(
                outputFormatter.accordionOpenTag
            )
        }
        for thisTest in group.subtests {
            lines.append(
                actionTestFileStatusString(for: thisTest, failureSummaries: failureSummaries)
            )
        }
        if !outputFormatter.accordionCloseTag.isEmpty {
            lines.append(
                outputFormatter.accordionCloseTag
            )
        }
        return lines
    }
    
    private func actionTestFileStatusString(for testData: ActionTestMetadata, failureSummaries: [TestFailureIssueSummary]) -> String {
        let duration = numFormatter.unwrappedString(for: testData.duration)
        let icon = testData.isFailed ? "✖︎": "✓"
        let testTitle = "\(icon) \(testData.name) (\(duration))"
        let testCaseName = testData.identifier.replacingOccurrences(of: "/", with: ".")
        if let summary = failureSummaries.first(where: { $0.testCaseName == testCaseName }) {
            return actionTestFailureStatusString(with: testTitle, and: summary)
        } else {
            return outputFormatter.singleTestItem(testTitle, failed: testData.isFailed)
        }
    }
    
    private func actionTestFailureStatusString(with header: String, and failure: TestFailureIssueSummary) -> String {
        return outputFormatter.failedTestItem(header, message: failure.message)
    }
}

private extension ActionTestSummaryGroup {
    var hasFailedTests: Bool {
        for test in subtests {
            if test.isFailed {
                return true
            }
        }
        for subGroup in subtestGroups {
            if subGroup.hasFailedTests {
                return true
            }
        }
        return false
    }
}

extension ActionTestMetadata {
    var isFailed: Bool {
        return testStatus != "Success"
    }
}

extension ActionTestSummaryGroup {
    var nameString: String {
        return name ?? "Unnamed"
    }
}
