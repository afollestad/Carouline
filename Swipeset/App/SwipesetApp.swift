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
    /// One decode cache for every window, reading the library's store.
    @State private var imageLoader: DiskImageLoader
    #if DEBUG
    @State private var debug: DebugSettings
    #endif

    init() {
        #if DEBUG
        let debug = DebugSettings.fromLaunchArguments()
        _debug = State(initialValue: debug)
        let store = debug.usesSampleProjects ? SampleStore.make() : ProjectStore()
        #else
        let store = ProjectStore()
        #endif
        _library = State(initialValue: ProjectLibrary(store: store))
        _imageLoader = State(initialValue: DiskImageLoader(paths: store.paths))
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
            .environment(\.imageLoader, imageLoader)
            .environment(debug)
        #else
        ContentView(library: library)
            .environment(\.imageLoader, imageLoader)
        #endif
    }
}
