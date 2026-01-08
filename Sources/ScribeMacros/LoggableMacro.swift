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
        var options = parseLogOptions(from: node)

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
            if let decl = declaration.as(EnumDeclSyntax.self) {
                options.name = decl.name.text
            } else if let decl = declaration.as(StructDeclSyntax.self) {
                options.name = decl.name.text
            } else if let decl = declaration.as(ClassDeclSyntax.self) {
                options.name = decl.name.text
            } else {
                return []
            }
        }

        var members: [DeclSyntax] = []

        if let categoryExpr = options.categoryExpr {
            // If the user provided a category, then make computed static var
            members.append(
                DeclSyntax(
                    """
                    public static var _logCategory: LogCategory {
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
                    public static let _logCategory: LogCategory = LogCategory("\(raw: name)")
                    """
                )
            )
        }

        switch options.style {
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
    /// - `@Loggable(.static)`
    /// - `@Loggable(category: .network)`
    /// - `@Loggable("network", .static)`
    /// - `@Loggable(category: .network, .instance)`
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
