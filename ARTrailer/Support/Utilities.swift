/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Utility functions and type extensions used throughout the projects.
 */

import Foundation

func readKey(key: String) -> String {
    if let path = Bundle.main.path(forResource: "Keys", ofType: "plist"),
        let dict = NSDictionary(contentsOfFile: path){
        return dict.value(forKey: key) as! String
    }
    return ""
}
