//
//  LuaLanguageSupport.swift
//  NR Status
//

import Foundation
import RegexBuilder
import LanguageSupport

private let luaKeywords =
  [ "and", "break", "do", "else", "elseif", "end", "false", "for", "function", "goto", "if", "in", "local", "nil",
    "not", "or", "repeat", "return", "then", "true", "until", "while" ]

// what the script runtime and the Lua standard library give a script to work with
private let luaBuiltins =
  [ "emit", "results", "print", "pairs", "ipairs", "tostring", "tonumber", "type", "select", "pcall", "error",
    "assert", "table", "string", "math", "os" ]

extension LanguageConfiguration {

  /// Language configuration for the Lua in script cells.
  ///
  /// A leading `--[[ ]]` comment holds the chart format, so it is a comment here like any other.
  public static func lua(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
    let numberRegex: Regex<Substring> = Regex {
      ChoiceOf {
        Regex { /0[xX]/; hexalLit; Optionally { "."; hexalLit }; Optionally { hexponentLit } }
        Regex { decimalLit; "."; decimalLit; Optionally { exponentLit } }
        Regex { decimalLit; exponentLit }
        decimalLit
      }
    }
    let identifierRegex: Regex<Substring> = Regex {
      identifierHeadCharacters
      ZeroOrMore { identifierCharacters }
    }
    let operatorRegex = Regex {
      ChoiceOf {
        Regex { operatorHeadCharacters; ZeroOrMore { operatorCharacters } }
        Regex { "."; OneOrMore { CharacterClass(operatorCharacters, .anyOf(".")) } }
      }
    }
    return LanguageConfiguration(name: "Lua",
                                 supportsSquareBrackets: false,
                                 supportsCurlyBrackets: true,
                                 caseInsensitiveReservedIdentifiers: false,
                                 indentationSensitiveScoping: true,
                                 stringRegex: /"(?:\\.|[^"\\\n])*+"|'(?:\\.|[^'\\\n])*+'/,
                                 characterRegex: nil,
                                 numberRegex: numberRegex,
                                 singleLineComment: "--",
                                 nestedComment: (open: "--[[", close: "]]"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: luaKeywords,
                                 reservedOperators: luaBuiltins,
                                 languageService: languageService)
  }
}
