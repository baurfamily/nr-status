//
//  NrqlLanguageSupport.swift
//  NR Status
//
//  Created by Eric Baur on 10/15/24.
//

import Foundation
import RegexBuilder
import LanguageSupport


private let nrqlReservedIdentifiers =
  [ "SELECT", "FROM", "AS", "COMPARE WITH", "EXTRAPOLATE", "FACET", "CASES", "ORDER BY", "JOIN", "LIMIT", "OFFSET", "SHOW EVENT TYPES", "SINCE", "SLIDE BY", "TIMESERIES", "UNTIL", "WHERE", "WITH METRIC_FORMAT", "WITH", "TIMEZONE", "LIMIT", "IN", "NOT", "LIKE", "RLIKE", "IS", "AND", "OR", "NULL", "TRUE", "FALSE" ]

private let nrqlReservedOperators =
  [".", "(", ")", "<", ">", "=", "week", "weeks", "ago", "minutes", "minute", "hour", "hours", "months", "month", "day", "days", "second", "seconds", "aggregationendtime", "apdex", "average", "bucketPercentile", "cardinality", "cdfPercentage", "count", "derivative", "earliest", "filter", "funnel", "histogram", "keyset", "latest", "latestrate", "max", "median", "min", "percentage", "percentile", "predictLinear", "rate", "stdvar", "sum", "uniqueCount", "uniques", "accountId", "aparse", "blob", "buckets", "concat", "convert", "capture", "decode", "dimensions", "encode", "cidrAddress", "eventType", "getField", "getCdfCount", "if", "jparse", "length", "lookup", "lower", "mapKeys", "mapValues", "minuteOf", "mod", "position", "round", "stddev", "string", "substring", "toDatetime", "toTimestamp", "upper" ]

extension LanguageConfiguration {

  /// Language configuration for NRQL (New Relic Query Language
  ///
  public static func nrql(_ languageService: LanguageService? = nil) -> LanguageConfiguration {
    let numberRegex: Regex<Substring> = Regex {
      optNegation
      ChoiceOf {
        Regex { /0b/; binaryLit }
        Regex { /0o/; octalLit }
        Regex { /0x/; hexalLit }
        Regex { /0x/; hexalLit; "."; hexalLit; Optionally { hexponentLit } }
        Regex { decimalLit; "."; decimalLit; Optionally { exponentLit } }
        Regex { decimalLit; exponentLit }
        decimalLit
      }
    }
    let plainIdentifierRegex: Regex<Substring> = Regex {
      identifierHeadCharacters
      ZeroOrMore {
        identifierCharacters
      }
    }
    let identifierRegex = Regex {
      ChoiceOf {
        plainIdentifierRegex
        Regex { "`"; plainIdentifierRegex; "`" }
        Regex { "$"; decimalLit }
        Regex { "$"; plainIdentifierRegex }
      }
    }
    let operatorRegex = Regex {
      ChoiceOf {

        Regex {
          operatorHeadCharacters
          ZeroOrMore {
            operatorCharacters
          }
        }

        Regex {
          "."
          OneOrMore {
            CharacterClass(operatorCharacters, .anyOf("."))
          }
        }
      }
    }
    return LanguageConfiguration(name: "NRQL",
                                 supportsSquareBrackets: false,
                                 supportsCurlyBrackets: false,
                                 caseInsensitiveReservedIdentifiers: true,
                                 stringRegex: /\"(?:\\\"|[^\"])*+\"/,
                                 characterRegex: nil,
                                 numberRegex: numberRegex,
                                 singleLineComment: "//",
                                 nestedComment: (open: "/*", close: "*/"),
                                 identifierRegex: identifierRegex,
                                 operatorRegex: operatorRegex,
                                 reservedIdentifiers: nrqlReservedIdentifiers,
                                 reservedOperators: nrqlReservedOperators,
                                 languageService: languageService)
  }
}
