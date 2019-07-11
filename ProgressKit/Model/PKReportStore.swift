//
//  PKReportStore.swift
//  ProgressKit
//
//  Copyright © 2018 ProgressKit authors
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation

public class PKReportStore: PKNotificationHandler {
    
    public static let standard = PKReportStore()
    
    let baseURL: URL?
    
    public init(suiteName: String? = nil){
        if let suiteName = suiteName {
            self.baseURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: suiteName)
        } else {
            self.baseURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        }
    }
    
    private enum FileName: String {
        case reports = "Reports"
    }
    
    // MARK: Last Modified
    
    public func lastModified() throws -> Date? {
        return try lastModified(fileNamed: .reports)
    }
    
    
    // MARK: SAVE
    
    public func save(report saveItem: PKReport) throws {
        var allItems = try loadReports()
        var needsInsert = true
        
        for (i, item) in allItems.enumerated() {
            guard item.identifier == saveItem.identifier else { continue }
            needsInsert = false
            allItems[i] = saveItem
            break
        }
        
        if needsInsert {
            allItems.append(saveItem)
        }
        
        try write(fileNamed: .reports, with: allItems)
    }
    
    public func save(all reports: [PKReport]) throws {
        try write(fileNamed: .reports, with: reports)
    }
    
    
    // MARK: DELETE
    
    public func delete(report deleteItem: PKReport) throws {
        var allItems = try loadReports()
        
        for (i, item) in allItems.enumerated() {
            guard item.identifier == deleteItem.identifier else { continue }
            allItems.remove(at: i)
            break
        }
        
        try write(fileNamed: .reports, with: allItems)
    }
    
    
    // MARK: READ
    
    public func loadReports() throws -> [PKReport] {
        return try read(fileNamed: .reports)
    }
    
    
    public func loadReports(withDisplayStyle displayStyle: PKDisplayStyle) throws -> [PKReport] {
        return try loadReports().filter{ $0.displayStyle == displayStyle }
    }
    
    
    public func loadReports(groupedByTimeRangWithDisplayStyle displayStyle: PKDisplayStyle, filteredBy isIncluded: (((PKReport)) -> Bool) = { _ in return true }) throws -> [[PKReport]] {
        var noTimeRange = [PKReport]()
        var timeRangeGrouped: [PKTimeRange: [PKReport]] = [:]
        
        try loadReports(withDisplayStyle: displayStyle).forEach{
            guard isIncluded($0) else { return }
            
            guard let timeRange = $0.timeRange else {
                noTimeRange.append($0)
                return
            }
            if timeRangeGrouped[timeRange] == nil{
                timeRangeGrouped[timeRange] = []
            }
            timeRangeGrouped[timeRange]?.append($0)
        }
        
        var allGrouped = [[PKReport]]()
        if !noTimeRange.isEmpty {
            allGrouped.append(noTimeRange)
        }
        
        for timeRange in PKTimeRange.availableTimeRanges {
            guard let thisGrouped = timeRangeGrouped[timeRange], !thisGrouped.isEmpty else { continue }
            allGrouped.append(thisGrouped)
        }
        
        return allGrouped
    }
    
    
    // MARK: HELPERS
    
    private func lastModified(fileNamed fileName: FileName) throws -> Date? {
        guard let baseURL = baseURL else {
            return nil
        }
        let url = baseURL.appendingPathComponent(fileName.rawValue).appendingPathExtension("plist")
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        return attributes[.modificationDate] as? Date ?? attributes[.creationDate] as? Date
    }
    
    private func write(fileNamed fileName: FileName, with items: [PKReport]) throws {
        guard let baseURL = baseURL else {
            return
        }
        let url = baseURL.appendingPathComponent(fileName.rawValue).appendingPathExtension("plist")
        let encoder = PropertyListEncoder()
        
        try encoder.encode(items).write(to: url)
        
        post(notification: .reportStoreDidChange)
    }
    
    private func read(fileNamed fileName: FileName) throws -> [PKReport] {
        guard let baseURL = baseURL else {
            return []
        }
        
        let url = baseURL.appendingPathComponent(fileName.rawValue).appendingPathExtension("plist")
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        
        let data = try Data(contentsOf: url)
        let decoder = PropertyListDecoder()
        
        switch fileName {
        case .reports: return try decoder.decode([PKReport].self, from: data)
        }
    }
}
