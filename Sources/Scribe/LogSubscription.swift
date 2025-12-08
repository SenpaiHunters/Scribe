//
//  LogSubscription.swift
//  Scribe
//
//  Created by Kami on 08/12/2025.
//

import Foundation

/// Unique identifier for a registered log subscription.
///
/// Used for both sink callbacks and async stream listeners.
public struct LogSubscription: Hashable, Sendable {
    /// Unique identifier for the subscription instance.
    let id: UUID

    /// Optional category filter associated with this subscription.
    let categories: Set<LogCategory>?

    /// Creates a new subscription with optional category filtering.
    ///
    /// - Parameter categories: Categories this subscription should receive. `nil` receives all.
    init(categories: Set<LogCategory>?) {
        id = UUID()
        self.categories = categories
    }
}
