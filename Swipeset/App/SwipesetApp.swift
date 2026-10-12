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

    /// One library for every window, so two iPad windows on the same project never save over
    /// each other's changes.
    @State private var library: ProjectLibrary
    #if DEBUG
    @State private var debug: DebugSettings
    #endif

    init() {
        #if DEBUG
        let debug = DebugSettings.fromLaunchArguments()
        _debug = State(initialValue: debug)
        _library = State(initialValue: ProjectLibrary(store: debug.usesSampleProjects ? SampleStore.make() : ProjectStore()))
        #else
        _library = State(initialValue: ProjectLibrary(store: ProjectStore()))
        #endif
    }

    var body: some Scene {
        WindowGroup {
            if Self.isHostingTests {
                Color.clear
            } else {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        #if DEBUG
        ContentView(library: library)
            .environment(debug)
        #else
        ContentView(library: library)
        #endif
    }
}
