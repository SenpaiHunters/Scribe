//
//  LogCategory.swift
//  Scribe
//
//  Created by Kai Azim on 2025-12-07.
//

import Foundation

/// Groups logs under a shared, identifiable category.
///
/// By default, categories are generated automatically on a per-file basis when using the `Log.*` functions.
/// You can also define your own categories explicitly by extending `LogCategory`:
///
/// ```swift
/// extension LogCategory {
///     static let backend = LogCategory("Backend")
/// }
/// ```
///
/// This allows the same category to be reused consistently across multiple files.
public struct LogCategory: Sendable, Hashable {
    public init(_ name: String) {
        self.name = name
    }

    public let name: String
}
