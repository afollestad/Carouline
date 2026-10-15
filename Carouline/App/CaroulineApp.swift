//
//  CaroulineApp.swift
//  Carouline
//

import SwiftUI
import TipKit

@main
struct CaroulineApp: App {
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
    /// Whether TipKit is configured, which the sample's tour needs. Never under tests, whose
    /// snapshots must not show a tip.
    private let offersTours: Bool
    #if DEBUG
    @State private var debug: DebugSettings
    #endif

    init() {
        #if DEBUG
        let debug = DebugSettings.fromLaunchArguments()
        _debug = State(initialValue: debug)
        let store = switch debug.store {
        case .samples: SampleStore.make(SampleProjects.all, missingImage: debug.missesSampleImage)
        case .demo: SampleStore.make(DemoProjects.all)
        case .firstLaunch: SampleStore.makeFirstLaunch()
        case nil: ProjectStore()
        }
        #else
        let store = ProjectStore()
        #endif
        _library = State(initialValue: ProjectLibrary(store: store, makeSample: { SampleProjects.firstLaunch }))
        _imageLoader = State(initialValue: DiskImageLoader(paths: store.paths))
        // Immediate, so each of the tour's tips follows the last rather than waiting a day.
        var tipOptions: [Tips.ConfigurationOption] = [.displayFrequency(.immediate)]
        #if DEBUG
        if debug.store == .firstLaunch {
            tipOptions.append(.datastoreLocation(.url(SampleStore.firstLaunchTips)))
        }
        #endif
        offersTours = !Self.isHostingTests && (try? Tips.configure(tipOptions)) != nil
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
            .environment(\.offersTours, offersTours)
            .environment(debug)
        #else
        ContentView(library: library)
            .environment(\.imageLoader, imageLoader)
            .environment(\.offersTours, offersTours)
        #endif
    }
}
