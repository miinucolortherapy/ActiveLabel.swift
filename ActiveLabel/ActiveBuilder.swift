//
//  ActiveBuilder.swift
//  ActiveLabel
//
//  Created by Pol Quintana on 04/09/16.
//  Copyright © 2016 Optonaut. All rights reserved.
//

import Foundation

typealias ActiveFilterPredicate = ((String) -> Bool)

struct ActiveBuilder {

    static func createElements(type: ActiveType, from text: String, range: NSRange, filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {
        switch type {
        case .mention, .hashtag:
            return createElementsIgnoringFirstCharacter(from: text, for: type, range: range, filterPredicate: filterPredicate)
        case .url:
            return createElements(from: text, for: type, range: range, filterPredicate: filterPredicate)
        case .custom:
            return createElements(from: text, for: type, range: range, minLength: 0, filterPredicate: filterPredicate)
        case .preview:
            return createElements(from: text, for: type, range: range, filterPredicate: filterPredicate)
        }
    }

    static func createURLElements(from text: String, range: NSRange, maximumLength: Int?) -> ([ElementTuple], String) {
        let type = ActiveType.url
        var text = text
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        var elements: [ElementTuple] = []

        var activeRange = text.startIndex..<text.endIndex
        for match in matches where match.range.length > 2 {
            let word = nsstring.substring(with: match.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)

            guard let maxLength = maximumLength, word.count > maxLength else {
                if let wordRange = text.range(of: word, range: activeRange) {
                    activeRange = wordRange.upperBound..<activeRange.upperBound
                    let range = maximumLength == nil ? match.range : NSRange(wordRange, in: text)
                    let element = ActiveElement.create(with: type, text: word)
                    elements.append((range, element, type))
                }
                continue
            }

            let trimmedWord = word.trim(to: maxLength)
            text = text.replacingOccurrences(of: word, with: trimmedWord)
            activeRange = activeRange.lowerBound..<text.endIndex
            
            if let wordRange = text.range(of: trimmedWord, range: activeRange) {
                activeRange = wordRange.upperBound..<activeRange.upperBound
                let range = NSRange(wordRange, in: text)
                let element = ActiveElement.url(original: word, trimmed: trimmedWord)
                elements.append((range, element, type))
            }
        }
        return (elements, text)
    }
    
    static func createPreviewElements(type: ActiveType,
                                     from text: String,
                                     preview: String?,
                                     range: NSRange,
                                     filterPredicate: ActiveFilterPredicate?) -> ([ElementTuple], String) {
        
        var text = text
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        var elements: [ElementTuple] = []
        
        for match in matches where match.range.length > 1 {
            let word = nsstring.substring(with: match.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if filterPredicate?(word) ?? true {
                guard let preview = preview else {
                    let element = ActiveElement.create(with: type, text: word)
                    elements.append((match.range, element, type))
                    continue
                }
                
                if let searchRange = text.range(of: word) {
                    text = text.replacingOccurrences(of: word, with: preview, range: searchRange)
                    let previewLength = preview.distance(from: preview.startIndex, to: preview.endIndex)
                    let previewRangeUpperBound = text.index(searchRange.lowerBound, offsetBy: previewLength)
                    let previewRange = searchRange.lowerBound..<previewRangeUpperBound
                    let newRange = NSRange(previewRange, in: text)
                    let element = ActiveElement.preview(original: word, preview: preview)
                    elements.append((newRange, element, type))
                }
            }
        }
        return (elements, text)
    }

    private static func createElements(from text: String,
                                            for type: ActiveType,
                                                range: NSRange,
                                                minLength: Int = 1,
                                                filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {

        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        var elements: [ElementTuple] = []

        for match in matches where match.range.length > minLength {
            let word = nsstring.substring(with: match.range)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if filterPredicate?(word) ?? true {
                let element = ActiveElement.create(with: type, text: word)
                elements.append((match.range, element, type))
            }
        }
        return elements
    }

    private static func createElementsIgnoringFirstCharacter(from text: String,
                                                                  for type: ActiveType,
                                                                      range: NSRange,
                                                                      filterPredicate: ActiveFilterPredicate?) -> [ElementTuple] {
        let matches = RegexParser.getElements(from: text, with: type.pattern, range: range)
        let nsstring = text as NSString
        var elements: [ElementTuple] = []

        for match in matches where match.range.length > 2 {
            let range = NSRange(location: match.range.location + 1, length: match.range.length - 1)
            var word = nsstring.substring(with: range)
            if word.hasPrefix("@") {
                word.remove(at: word.startIndex)
            }
            else if word.hasPrefix("#") {
                word.remove(at: word.startIndex)
            }

            if filterPredicate?(word) ?? true {
                let element = ActiveElement.create(with: type, text: word)
                elements.append((match.range, element, type))
            }
        }
        return elements
    }
}
