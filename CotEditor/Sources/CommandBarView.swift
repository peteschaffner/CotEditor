//
//  CommandBarView.swift
//
//  CotEditor
//  https://coteditor.com
//
//  Created by 1024jp on 2023-11-20.
//
//  ---------------------------------------------------------------------------
//
//  © 2023 1024jp
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

import SwiftUI
import AppKit

struct CommandBarView: View {
    
    struct Candidate: Identifiable {
        
        var command: ActionCommand
        var matches: [ActionCommand.MatchedPath]
        var score: Int
        var id: UUID  { self.command.id }
    }
    
    
    weak var parent: NSWindow?
    
    @Environment(\.controlActiveState) private var controlActiveState
    
    @State private var input: String = ""
    @State var candidates: [Candidate] = []
    
    @State private var commands: [ActionCommand] = []
    @State private var selection: ActionCommand.ID?
    
    @State private var keyMonitor: Any?
    
    
    var body: some View {
        
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Image(systemName: "magnifyingglass")
                TextField("Quick Actions", text: $input)
                    .onSubmit(self.perform)
                    .fontWeight(.light)
                    .textFieldStyle(.plain)
            }
            .font(.system(size: 20))
            .padding(12)
            
            if !self.candidates.isEmpty {
                Divider()
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        LazyVStack {
                            ForEach(self.candidates) { candidate in
                                ActionCommandView(command: candidate.command, matches: candidate.matches)
                                    .selected(candidate.id == self.selection)
                                    .id(candidate.id)
                                    .onTapGesture {
                                        self.selection = candidate.id
                                        self.perform()
                                    }
                            }
                        }.padding(.horizontal, 12)
                    }.onChange(of: self.selection) { id in
                        proxy.scrollTo(id)
                    }
                }
                .padding(.vertical, 12)
                .frame(maxHeight: 300)
                .fixedSize(horizontal: false, vertical: true)
            }
        }
        .onChange(of: self.input) { input in
            self.candidates = self.commands
                .compactMap {
                    guard let result = $0.match(command: input) else { return nil }
                    return Candidate(command: $0, matches: result.result, score: result.score)
                }
                .sorted(\.score)
            self.selection = self.candidates.first?.id
        }
        .onChange(of: self.controlActiveState) { state in
            switch state {
                case .key, .active:
                    self.commands = NSApp.mainMenu?.items
                        .flatMap(\.actionCommands) ?? []
                    self.keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
                        if let key = event.specialKey,
                           event.modifierFlags.isDisjoint(with: [.shift, .control, .option, .command])
                        {
                            switch key {
                                case .downArrow, .upArrow:
                                    self.move(down: (key == .downArrow))
                                    return nil
                                default:
                                    break
                            }
                        }
                        return event
                    }
                    
                case .inactive:
                    self.input = ""
                    if let keyMonitor {
                        NSEvent.removeMonitor(keyMonitor)
                        self.keyMonitor = nil
                    }
                    
                @unknown default:
                    break
            }
        }
        .frame(width: 500)
        .ignoresSafeArea()
    }
    
    
    /// Move the selection to the next one, if any exists.
    ///
    /// - Parameter down: Whether move down or up the selection.
    private func move(down: Bool) {
        
        guard
            let index = self.candidates.firstIndex(where: { $0.id == self.selection }),
            let candidate = self.candidates[safe: index + (down ? 1 : -1)]
        else { return }
        
        self.selection = candidate.id
    }
    
    
    /// Perform the selected command and close the view.
    private func perform() {
        
        // first close the command bar and then take the action
        // so that the action is delivered to the correct (first) responder.
        self.parent?.close()
        
        if let command = self.candidates.first(where: { $0.id == self.selection })?.command {
            command.perform()
        }
    }
}


private struct ActionCommandView: View {
    
    @Environment(\.colorSchemeContrast) var colorContrast
    
    let command: ActionCommand
    let matches: [ActionCommand.MatchedPath]
    
    var isSelected = false
    
    
    var body: some View {
        
        HStack {
            Image(systemName: self.command.kind.systemImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .fontWeight(.light)
                .foregroundStyle(self.isSelected ? .primary : .secondary)
                .frame(width: 32, height: 20, alignment: .center)
            
            VStack(alignment: .leading) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    ForEach(Array(self.matches.enumerated()), id: \.offset) { (offset, match) in
                        if offset > 0 {
                            Image(systemName: "chevron.compact.right")
                                .opacity(0.4)
                        }
                        Text(self.attributed(match.string, in: match.ranges, font: .body))
                            .layoutPriority((offset == 0) ? 10 : Double(offset))
                    }
                }
                .foregroundStyle((self.isSelected && self.colorContrast == .standard) ? Color.selectedMenuItemText.opacity(0.8) : .primary)
                
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    ForEach(Array(self.command.paths.enumerated()), id: \.offset) { (offset, path) in
                        if offset > 0 {
                            Image(systemName: "chevron.compact.right")
                                .opacity(0.4)
                        }
                        Text(path)
                            .layoutPriority((offset == 0) ? 10 : Double(offset))
                    }
                }
                .foregroundStyle(self.isSelected ? .primary : .secondary)
                .controlSize(.small)
            }
            
            Spacer()
            
            if let shortcut = self.command.shortcut {
                Text(shortcut.symbol)
                    .foregroundStyle(self.isSelected ? .primary : .secondary)
                    .fixedSize()
                    .layoutPriority(100)
            }
        }
        .lineLimit(1)
        .padding(.vertical, 4)
        .padding(.horizontal)
        .contentShape(Rectangle())  // for clicking
        .foregroundStyle(self.isSelected ? Color.selectedMenuItemText : .primary)
        .background(self.isSelected ? Color.accentColor : .clear,
                    in: RoundedRectangle(cornerRadius: 6))
    }
    
    
    /// Set the selecting state of the receiver.
    ///
    /// - Parameter selected: The selecting state to change.
    func selected(_ selected: Bool = true) -> Self {
        
        var view = self
        view.isSelected = selected
        return view
    }
    
    
    /// Return an AttributedString by highlighting the given ranges by taking the view states into account.
    ///
    /// - Parameters:
    ///   - string: The base string to create the attributed string.
    ///   - ranges: The ranges for the given `string` to highlight.
    ///   - font: The base font.
    /// - Returns: An attributed string.
    private func attributed(_ string: String, in ranges: [Range<String.Index>], font: Font) -> AttributedString {
        
        let attributed = AttributedString(string)
        
        return ranges
            .compactMap { Range($0, in: attributed) }
            .reduce(into: attributed) { (string, range) in
                string[range].font = font.weight(.bold)
                string[range].foregroundColor = self.isSelected ? Color.selectedMenuItemText : nil
            }
    }
}


private extension ActionCommand.Kind {
    
    var systemImage: String {
        
        switch self {
            case .command: "filemenu.and.selection"
            case .outline: "list.bullet.rectangle"
            case .script: "applescript.fill"
        }
    }
}


private extension Color {
    
    static let selectedMenuItemText = Color(nsColor: .selectedMenuItemTextColor)
}



// MARK: - Preview

#Preview {
    let candidates: [CommandBarView.Candidate] = [
        .init(command: .init(kind: .command, title: "Find…",
                             paths: ["Find"],
                             shortcut: Shortcut("f", modifiers: .command),
                             action: #selector(NSResponder.yank)),
              matches: [.init(string: "Find…", ranges: [])],
              score: 0),
        .init(command: .init(kind: .command, title: "Fortran",
                             paths: ["Format", "Syntax"],
                             action: #selector(NSResponder.yank)),
              matches: [
                .init(string: "Syntax",
                      ranges: [Range(NSRange(0..<2), in: "Syntax")!]),
                .init(string: "Fortran", ranges: []),
              ],
              score: 0),
    ]
    
    return CommandBarView(candidates: candidates)
}


#Preview("Command View") {
    ActionCommandView(
        command: .init(kind: .command, title: "Swift",
                       paths: ["Format", "Syntax"],
                       shortcut: Shortcut("s", modifiers: [.command]),
                       action: #selector(NSResponder.yank)),
        matches: [.init(string: "Swift", ranges: [])],
        isSelected: true
    )
    .fixedSize(horizontal: false, vertical: true)
    .frame(width: 300)
    .padding(12)
}