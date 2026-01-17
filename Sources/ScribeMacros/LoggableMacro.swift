//
//  LoggableMacro.swift
//  Scribe
//
//  Created by Kai Azim on 2026-01-07.
//

import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

// MARK: - MacrosPlugin

@main
struct MacrosPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        LoggableMacro.self
    ]
}

// MARK: - LoggableMacro

struct LoggableMacro: MemberMacro {
    static func expansion(
        of node: AttributeSyntax,
        providingMembersOf declaration: some DeclSyntaxProtocol,
        conformingTo protocolType: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [DeclSyntax] {
        guard let typeName = getTypeName(declaration: declaration) else {
            return []
        }

        let accessLevel = getAccessLevel(declaration: declaration)
        let accessPrefix = accessLevel.isEmpty ? "" : "\(accessLevel) "
        var options = parseLogOptions(from: node)

        // If both a custom name and category are passed in, they conflict.
        if options.name != nil, options.categoryExpr != nil {
            context.diagnose(
                Diagnostic(
                    node: Syntax(node),
                    message: LoggableArgumentConflictDiagnostic()
                )
            )
            return []
        }

        // If no explicit category is provided, fall back to type name
        if options.categoryExpr == nil, options.name == nil {
            options.name = typeName
        }

        var members: [DeclSyntax] = []

        if let categoryExpr = options.categoryExpr {
            // If the user provided a category, then make computed static var
            members.append(
                DeclSyntax(
                    """
                    \(raw: accessPrefix)static var logCategory: LogCategory {
                        \(categoryExpr)
                    }
                    """
                )
            )
        } else if let name = options.name {
            // Otherwise, create a new category
            members.append(
                DeclSyntax(
                    """
                    \(raw: accessPrefix)static let logCategory: LogCategory = LogCategory("\(raw: name)")
                    """
                )
            )
        }

        switch options.style {
        case .static:
            members.append(
                DeclSyntax(
                    """
                    \(raw: accessPrefix)static let log = Log(category: logCategory)
                    """
                )
            )
        case .instance:
            members.append(
                DeclSyntax(
                    """
                    private static let _log = Log(category: \(raw: typeName).logCategory)
                    """
                )
            )

            members.append(
                DeclSyntax(
                    """
                    \(raw: accessPrefix)var log: Log { \(raw: typeName)._log }
                    """
                )
            )
        }

        return members
    }

    /// Extracts the name of the type from the declaration.
    ///
    /// This is used to:
    /// - Generate the default `LogCategory` name when no custom name is provided.
    /// - Reference the type explicitly in the generated `_log` property (e.g., `TypeName.logCategory`).
    ///   This is because using `Self.<>` can lead to covariant self errors.
    ///
    /// Returns `nil` if the declaration is not a supported type (enum, struct, or class).
    private static func getTypeName(declaration: some DeclSyntaxProtocol) -> String? {
        if let decl = declaration.as(EnumDeclSyntax.self) {
            decl.name.text
        } else if let decl = declaration.as(StructDeclSyntax.self) {
            decl.name.text
        } else if let decl = declaration.as(ClassDeclSyntax.self) {
            decl.name.text
        } else {
            nil
        }
    }

    /// Extracts the access level modifier from the declaration.
    ///
    /// This ensures the generated properties (`logCategory`, `log`) match the access level of the type they're
    /// attached to, rather than being hardcoded to `public`.
    ///
    /// Returns an empty string if no explicit access level is found.
    private static func getAccessLevel(declaration: some DeclSyntaxProtocol) -> String {
        let modifiers: DeclModifierListSyntax? = if let decl = declaration.as(EnumDeclSyntax.self) {
            decl.modifiers
        } else if let decl = declaration.as(StructDeclSyntax.self) {
            decl.modifiers
        } else if let decl = declaration.as(ClassDeclSyntax.self) {
            decl.modifiers
        } else {
            nil
        }

        guard let modifiers else { return "" }

        for modifier in modifiers {
            switch modifier.name.text {
            case "public",
                 "package",
                 "internal",
                 "fileprivate",
                 "private":
                return modifier.name.text
            default:
                continue
            }
        }

        return ""
    }

    /// Parses the logger name and style to be used with this macro.
    ///
    /// By default:
    /// - `categoryExpr` is `nil`
    /// - `name` is `nil`
    /// - `style` is `.instance`
    ///
    /// Supported forms:
    /// - `@Loggable`
    /// - `@Loggable("network")`
    /// - `@Loggable(type: .static)`
    /// - `@Loggable(category: .network)`
    /// - `@Loggable("network", type: .static)`
    /// - `@Loggable(category: .network, type: .instance)`
    private static func parseLogOptions(from node: AttributeSyntax) -> ParsedLogOptions {
        var name: String? = nil
        var categoryExpr: ExprSyntax? = nil
        var style: LogStyle = .instance

        guard let arguments = node.arguments?.as(LabeledExprListSyntax.self) else {
            return ParsedLogOptions(categoryExpr: nil, name: nil, style: style)
        }

        for argument in arguments {
            let expr = argument.expression

            // category: <expr>
            if argument.label?.text == "category" {
                categoryExpr = expr
                continue
            }

            // String literal → name
            if let stringLiteral = expr.as(StringLiteralExprSyntax.self) {
                name = stringLiteral.segments
                    .compactMap { $0.as(StringSegmentSyntax.self)?.content.text }
                    .joined()
                continue
            }

            // Member access → style (.static / .instance)
            if let memberAccess = expr.as(MemberAccessExprSyntax.self) {
                switch memberAccess.declName.baseName.text {
                case "static":
                    style = .static
                case "instance":
                    style = .instance
                default:
                    break
                }
            }
        }

        return ParsedLogOptions(
            categoryExpr: categoryExpr,
            name: name,
            style: style
        )
    }

    /// A style of log to be added via the macro. Make sure this matches the declarations over in the Scribe target!
    private enum LogStyle {
        /// Makes the `log` a static property.
        case `static`

        /// Makes the `log` an instance property.
        case instance
    }

    /// A struct to expose a type-safe version of the macro's arguments.
    private struct ParsedLogOptions {
        /// Explicit category expression, e.g. `.network`.
        var categoryExpr: ExprSyntax?

        /// The name of the LogCategory to generate. If the `name` and `categoryExpr` are `nil`, then the type name is
        /// used.
        var name: String?

        /// The style of log to be added via the macro.
        let style: LogStyle
    }
}

// MARK: - LoggableArgumentConflictDiagnostic

private struct LoggableArgumentConflictDiagnostic: DiagnosticMessage {
    var message: String {
        "`@Loggable` cannot specify both a custom name and a category. Use only one."
    }

    var diagnosticID: MessageID {
        MessageID(domain: "LoggableMacro", id: "nameAndCategoryConflict")
    }

    var severity: DiagnosticSeverity {
        .error
    }
}
