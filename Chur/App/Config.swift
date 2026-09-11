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
    ///
    /// DEBUG builds can pin the app to the bundle at runtime (hammer menu →
    /// "Use bundled content", or `DebugOverrides.forceBundledContent`) to test
    /// JSON edits that have not been published yet — remote content wins over
    /// the bundle by design, so an unpublished edit is otherwise invisible on
    /// any device that has ever refreshed. The vector suite sets it too.
    static var remoteContentEnabled: Bool {
        #if DEBUG
        if DebugOverrides.forceBundledContent { return false }
        #endif
        return true
    }
}

#if DEBUG
enum DebugOverrides {
    static let forceBundledContentKey = "debug.forceBundledContent"

    /// Read from standard defaults on every check rather than cached: the hammer
    /// menu flips it mid-session and the databases reload straight after.
    static var forceBundledContent: Bool {
        get { UserDefaults.standard.bool(forKey: forceBundledContentKey) }
        set { UserDefaults.standard.set(newValue, forKey: forceBundledContentKey) }
    }
}
#endif
