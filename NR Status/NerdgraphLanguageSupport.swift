import Foundation
import LanguageSupport

extension LanguageConfiguration {
    static func graphql(_ service: LanguageService? = nil) -> LanguageConfiguration {
        LanguageConfiguration(
            name: "GraphQL",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            caseInsensitiveReservedIdentifiers: false,
            indentationSensitiveScoping: true,
            stringRegex: /"(?:\\.|[^"\\])*"/,
            characterRegex: nil,
            numberRegex: /-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/,
            singleLineComment: "#",
            nestedComment: nil,
            identifierRegex: /[$A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: /[!$():=@\[\]{|}]+|\.\.\./,
            reservedIdentifiers: ["query", "mutation", "subscription", "fragment", "on", "true", "false", "null"],
            reservedOperators: [],
            languageService: service
        )
    }

    static func graphqlVariables(_ service: LanguageService? = nil) -> LanguageConfiguration {
        LanguageConfiguration(
            name: "JSON Variables",
            supportsSquareBrackets: true,
            supportsCurlyBrackets: true,
            caseInsensitiveReservedIdentifiers: false,
            indentationSensitiveScoping: true,
            stringRegex: /"(?:\\.|[^"\\])*"/,
            characterRegex: nil,
            numberRegex: /-?[0-9]+(?:\.[0-9]+)?(?:[eE][+-]?[0-9]+)?/,
            singleLineComment: nil,
            nestedComment: nil,
            identifierRegex: /[A-Za-z_][A-Za-z0-9_]*/,
            operatorRegex: /[{}\[\]:,]+/,
            reservedIdentifiers: ["true", "false", "null"],
            reservedOperators: [],
            languageService: service
        )
    }
}
