//
//  ContentView.swift
//  MoveClipBoard
//
//  Created by Erkam Kucet on 3.04.2026.
//

import SwiftUI
import ServiceManagement

struct ContentView: View {
    @State private var cm        = ClipboardManager()
    @State private var sm        = SimulatorManager()
    @State private var snm       = SnippetsManager()
    @State private var tab:      AppTab = .clipboard
    @State private var search    = ""
    @State private var showAdd   = false
    @State private var addPrefill = ""
    @State private var showLoginPrompt = false

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
            Divider()
            FooterBar()
        }
        .environment(cm)
        .environment(sm)
        .environment(snm)
        .frame(width: DS.width)
        .onAppear {
            if !UserDefaults.standard.bool(forKey: "hasPromptedLoginItem") {
                showLoginPrompt = true
            }
        }
        .alert("Start at Login?", isPresented: $showLoginPrompt) {
            Button("Yes") {
                try? SMAppService.mainApp.register()
                UserDefaults.standard.set(true, forKey: "hasPromptedLoginItem")
            }
            Button("No", role: .cancel) {
                UserDefaults.standard.set(true, forKey: "hasPromptedLoginItem")
            }
        } message: {
            Text("Would you like MoveClipBoard to start automatically when you log in?")
        }
        .sheet(isPresented: $showAdd) {
            AddSnippetSheet(isPresented: $showAdd, initialText: addPrefill)
                .environment(snm)
        }
    }
}

#Preview {
    ContentView()
}
