//
//  TrayRemovals.swift
//  Carouline
//

import Foundation
import Observation

/// Tray photos a pick left out, by their library originals.
nonisolated struct TrayRemoval: Hashable, Sendable {
    let projectID: UUID
    let originals: Set<String>
}

/// The tray photos a pick left out, waiting on whether to take them out of the tray, and those kept
/// when asked. The picker drops a photo it can't find, as one deleted from the library since, just
/// as it drops one unchecked, and the tray's copy may be the last, so it asks rather than taking it.
@Observable
final class TrayRemovals {
    /// The photos waiting on an answer.
    private(set) var pending: TrayRemoval?
    /// Library originals of tray photos kept when asked, which are asked about no more, since one
    /// deleted from the library is left out of every pick.
    private(set) var kept: Set<String> = []

    init(pending: TrayRemoval? = nil) {
        self.pending = pending
    }

    /// Asks about tray photos project `projectID`'s pick left out, other than those already kept,
    /// along with any still waiting from an earlier pick of the same project.
    func ask(about originals: Set<String>, in projectID: UUID) {
        var originals = originals.subtracting(kept)
        if let pending, pending.projectID == projectID {
            originals.formUnion(pending.originals)
        }
        guard !originals.isEmpty else {
            return
        }
        pending = TrayRemoval(projectID: projectID, originals: originals)
    }

    /// Keeps the photos waiting on an answer, and asks about them no more.
    func keep() {
        if let pending {
            kept.formUnion(pending.originals)
        }
        pending = nil
    }

    /// Drops the question, once none of the photos it asks about is left in the tray.
    func forget() {
        pending = nil
    }

    /// Takes the photos waiting on an answer out of the tray.
    func remove(from library: ProjectLibrary) {
        if let pending {
            library.removeFromTray(originals: pending.originals, in: pending.projectID)
        }
        pending = nil
    }
}
