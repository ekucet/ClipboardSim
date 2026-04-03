//
//  ContentView.swift
//  MoveClipBoard
//
//  Created by Erkam Kucet on 3.04.2026.
//

import SwiftUI

struct ContentView: View {
    @State private var cm        = ClipboardManager()
    @State private var sm        = SimulatorManager()
    @State private var snm       = SnippetsManager()
    @State private var tab:      AppTab = .clipboard
    @State private var search    = ""
    @State private var showAdd   = false
    @State private var addPrefill = ""

    var body: some View {
        VStack(spacing: 0) {
            HeaderBar(tab: $tab, showAdd: $showAdd, addPrefill: $addPrefill)
            Divider()
            SimulatorBar()
            Divider()
            switch tab {
            case .clipboard: ClipboardTab(search: $search)
            case .snippets:  SnippetsTab()
            }
        }
        .environment(cm)
        .environment(sm)
        .environment(snm)
        .frame(width: DS.width)
        .sheet(isPresented: $showAdd) {
            AddSnippetSheet(isPresented: $showAdd, initialText: addPrefill)
                .environment(snm)
        }
    }
}

#Preview {
    ContentView()
}
