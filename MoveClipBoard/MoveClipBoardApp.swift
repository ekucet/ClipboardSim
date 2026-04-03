//
//  MoveClipBoardApp.swift
//  MoveClipBoard
//
//  Created by Erkam Kucet on 3.04.2026.
//

import SwiftUI

@main
struct MoveClipBoardApp: App {
    var body: some Scene {
        MenuBarExtra("MoveClipBoard", systemImage: "doc.on.clipboard") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
