//
//  Config.swift
//  Chur
//
//  Single source of truth for app-level configuration values.
//  Update here when project IDs or client IDs change.
//

enum Config {
    static let googleClientID = "72421479384-khfht84hnp48i7svdvce61d06511eepu.apps.googleusercontent.com"
    static let sanityProjectID = "0fcg3g46"
    static let sanityDataset = "production"
}

enum FeatureFlags {
    /// News feed section on Home. Off for go-live; flip on when the feature is ready.
    static let homeNewsFeedEnabled = false

    /// Remote card/reward content from content.chur.app (see ROADMAP.md §P1).
    /// Off until the pipeline is verified on device — when off, the app reads
    /// bundled JSON exactly as it always has.
    static let remoteContentEnabled = true
}
