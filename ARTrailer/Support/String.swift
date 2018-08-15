//
//  String.swift
//  ARTrailer
//
//  Created by Wai Ting Cheung on 10/8/2018.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation

func correctText(text: String) -> String {    
    var result = text.removeCharacters(inCharacterSet: CharacterSet.punctuationCharacters)
    
    let checker = UITextChecker()
    let range = NSRange(location: 0, length: result.utf16.count)
    let misspelledRange = checker.rangeOfMisspelledWord(in: result, range: range, startingAt: 0, wrap: false, language: "en")
    
    if misspelledRange.location == NSNotFound {
        return result
    } else {
        guard var candidates = checker.guesses(forWordRange: misspelledRange, in: result, language: "en") else {
            return ""
        }
        if (!candidates.isEmpty) {
            candidates.sort(by: { (c1, c2) -> Bool in
                return levenshtein(w1: c1, w2: result) < levenshtein(w1: c2, w2: result)
            })
            return candidates[0]
        } else {
            return ""
        }
    }
}

extension String {
    // Adapted from https://stackoverflow.com/questions/29667419/how-can-i-remove-or-replace-all-punctuation-characters-from-a-string
    func removeCharacters(inCharacterSet forbiddenCharacters:CharacterSet) -> String
    {
        var filteredString = self
        while true {
            if let forbiddenCharRange = filteredString.rangeOfCharacter(from: forbiddenCharacters)  {
                filteredString.removeSubrange(forbiddenCharRange)
            }
            else {
                break
            }
        }
        
        return filteredString
    }
    
    func containsNoun() -> Bool {
        var hasNoun = false
        let tagger = NSLinguisticTagger(tagSchemes: [.lexicalClass], options: 0)
        tagger.string = self
        let range = NSRange(location: 0, length: self.utf16.count)
        let options: NSLinguisticTagger.Options = [.omitPunctuation, .omitWhitespace]
        tagger.enumerateTags(in: range, unit: .word, scheme: .lexicalClass, options: options) { tag, tokenRange, _ in
            if let tag = tag {
                // let word = (text as NSString).substring(with: tokenRange)
                if (tag.rawValue == "Noun") {
                    // print("\(word): \(tag)")
                    hasNoun = true
                }
            }
        }
        return hasNoun
    }
}
