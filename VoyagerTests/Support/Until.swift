//
//  Until.swift
//  VoyagerTests
//
//  Created by Angelo Carasig on 10/11/2026.
//

import Observation

// only wakes on observable reads - a condition over @ObservationIgnored state
// never re-runs and hangs until the suite time limit
@MainActor
func until(_ condition: @escaping @MainActor @Sendable () -> Bool) async {
    for await held in Observations(condition) where held { return }
}
