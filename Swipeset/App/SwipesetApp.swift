//
//  SwipesetApp.swift
//  Swipeset
//

import SwiftUI

@main
struct SwipesetApp: App {
    /// Tests run inside the app, which keeps running underneath them. Without this it would
    /// load projects from disk and sweep their files in the middle of a run.
    static var isHostingTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingTests {
                Color.clear
            } else {
                ContentView()
            }
        }
    }
}
