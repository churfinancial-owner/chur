//
//  BuildStamp.swift
//  Chur
//
//  Prints when the running binary was compiled, so "is the simulator actually
//  running my latest code?" is a line in the console rather than a guess.
//
//  Xcode compiles from disk and `git pull` writes to disk, so the only way to be
//  out of date is to not have rebuilt since pulling — which is invisible, because
//  a stale build looks identical to a fresh one. This makes it visible.
//
//  Reads the executable's modification date rather than a git SHA on purpose: no
//  build phase script, no Info.plist keys, nothing to wire up or keep in sync.
//

#if DEBUG
import Foundation

enum BuildStamp {

    static func log() {
        guard let compiledAt else {
            print("🧱 Chur build — compile time unavailable")
            return
        }

        let absolute = DateFormatter()
        absolute.dateFormat = "yyyy-MM-dd HH:mm:ss"

        let relative = RelativeDateTimeFormatter()
        relative.unitsStyle = .full

        // Deliberately Date() and not Date.current(): the time-travel debug tool
        // moves the app's clock, and a build stamp reported as "in 3 months" would
        // be worse than useless.
        let ago = relative.localizedString(for: compiledAt, relativeTo: Date())
        print("🧱 Chur build compiled \(absolute.string(from: compiledAt)) · \(ago)")
    }

    /// Modification date of the app binary — set when Xcode links it, so it is
    /// the compile time of the code actually running.
    private static var compiledAt: Date? {
        guard let executable = Bundle.main.executableURL,
              let attributes = try? FileManager.default.attributesOfItem(atPath: executable.path) else {
            return nil
        }
        return attributes[.modificationDate] as? Date
    }
}
#endif
