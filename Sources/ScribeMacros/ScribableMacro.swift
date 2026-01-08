//
//  ScribableMacro.swift
//  Scribe
//
//  Created by Kai Azim on 2026-01-07.
//

import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - MacrosPlugin

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        ScribableMacro.self
    ]
}

// MARK: - ScribableMacro

struct ScribableMacro: MemberMacro {
    /// A style of log to be added via the macro. Make sure this matches the declarations over in the Scribe target!
    enum LogStyle {
        /// Makes the `log` a static property.
        case `static`

        /// Makes the `log` an instance property.
        case instance
    }

    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclSyntaxProtocol,
        conformingTo protocolType: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        let name: String

        if let decl = declaration.as(EnumDeclSyntax.self) {
            name = decl.name.text
        } else if let decl = declaration.as(StructDeclSyntax.self) {
            name = decl.name.text
        } else if let decl = declaration.as(ClassDeclSyntax.self) {
            name = decl.name.text
        } else {
            return []
        }

        let style = parseLogStyle(from: node)

        var members: [DeclSyntax] = [
            DeclSyntax(
                """
                public static let _logCategory: LogCategory = LogCategory("\(raw: name)")
                """
            )
        ]

        switch style {
        case .static:
            members.append(
                DeclSyntax(
                    """
                    public static let log = Log(category: _logCategory)
                    """
                )
            )
        case .instance:
            members.append(
                DeclSyntax(
                    """
                    private static let _log = Log(category: Self._logCategory)
                    """
                )
            )

            members.append(
                DeclSyntax(
                    """
                    public var log: Log { Self._log }
                    """
                )
            )
        }

        return members
    }

    /// Parses the logger style to be used with this macro.
    ///
    /// By default, the `.instance` style is used, and the `.static` style is only used if explicitly set.
    ///
    /// Examples:
    /// - `@Scribable` -> instance style
    /// - `@Scribable(.static)` -> static style
    /// - `@Scribable(.instance)` -> instance style
    ///
    /// - Parameter node: The node associated with this macro. The first argument will be used to determine the style.
    /// - Returns: A LoggerStyle case depending on the node.
    private static func parseLogStyle(from node: AttributeSyntax) -> LogStyle {
        // When nothing is provided, assume .instance
        guard let tuple = node.arguments?.as(LabeledExprListSyntax.self),
              let first = tuple.first
        else {
            return .instance
        }

        let expr = first.expression

        // Only accept MemberAccessExprSyntax (.static or .instance)
        guard let memberAccess = expr.as(MemberAccessExprSyntax.self) else {
            return .instance
        }

        let identifier = memberAccess.declName.baseName.text

        switch identifier {
        case "static":
            return .static
        case "instance":
            return .instance
        default:
            return .instance
        }
    }
}
