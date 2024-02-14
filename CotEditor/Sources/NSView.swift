//
//  NSView.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2018-05-11.
//
//  ---------------------------------------------------------------------------
//
//  © 2018-2023 1024jp
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  https://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

import AppKit

extension NSView {
    
    /// The root view controller.
    final var viewControllerForSheet: NSViewController? {
        
        self.window?.windowController?.contentViewController
    }
}


extension NSView {
    
    /// Sends user feedback for the VoiceOver.
    ///
    /// - Parameters:
    ///   - announcement: The localized string to announce.
    ///   - priority: The announcement priority.
    final func requestAccessibilityAnnouncement(_ announcement: String, priority: NSAccessibilityPriorityLevel = .high) {
        
        NSAccessibility.post(element: self, notification: .announcementRequested,
                             userInfo: [.announcement: announcement,
                                        .priority: priority.rawValue])
    }
}


extension NSView {
    /// Recursively finds and returns the first descendant view that has the given class name.
    func firstDescendant(withClassName name: String) -> NSView? {
        for subview in subviews {
            if String(describing: type(of: subview)) == name {
                return subview
            } else if let found = subview.firstDescendant(withClassName: name) {
                return found
            }
        }

        return nil
    }

    /// Recursively finds and returns descendant views that have the given class name.
    func descendants(withClassName name: String) -> [NSView] {
        var result = [NSView]()

        for subview in subviews {
            if String(describing: type(of: subview)) == name {
                result.append(subview)
            }

            result += subview.descendants(withClassName: name)
        }

        return result
    }
}
