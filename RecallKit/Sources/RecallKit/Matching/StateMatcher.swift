import Foundation

/// Decides whether a free-text `distribution_pattern` plausibly covers the
/// user's state. The FDA field is unstructured ("Nationwide", "PA, DE, NJ",
/// "Only in NY.", "Distributed throughout CA and neighboring states"), so
/// this matcher errs on the side of inclusion for statewide/national wording.
public enum StateMatcher {

    /// Full state name -> USPS abbreviation.
    public static let abbreviations: [String: String] = [
        "alabama": "AL", "alaska": "AK", "arizona": "AZ", "arkansas": "AR",
        "california": "CA", "colorado": "CO", "connecticut": "CT", "delaware": "DE",
        "district of columbia": "DC", "florida": "FL", "georgia": "GA", "hawaii": "HI",
        "idaho": "ID", "illinois": "IL", "indiana": "IN", "iowa": "IA",
        "kansas": "KS", "kentucky": "KY", "louisiana": "LA", "maine": "ME",
        "maryland": "MD", "massachusetts": "MA", "michigan": "MI", "minnesota": "MN",
        "mississippi": "MS", "missouri": "MO", "montana": "MT", "nebraska": "NE",
        "nevada": "NV", "new hampshire": "NH", "new jersey": "NJ", "new mexico": "NM",
        "new york": "NY", "north carolina": "NC", "north dakota": "ND", "ohio": "OH",
        "oklahoma": "OK", "oregon": "OR", "pennsylvania": "PA", "rhode island": "RI",
        "south carolina": "SC", "south dakota": "SD", "tennessee": "TN", "texas": "TX",
        "utah": "UT", "vermont": "VT", "virginia": "VA", "washington": "WA",
        "west virginia": "WV", "wisconsin": "WI", "wyoming": "WY",
    ]

    /// Normalizes a user-provided state (full name or abbreviation, any case)
    /// to its uppercase abbreviation. Returns nil if unrecognized.
    public static func normalizeState(_ input: String) -> String? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        if let abbrev = abbreviations[trimmed] { return abbrev }
        let upper = trimmed.uppercased()
        if abbreviations.values.contains(upper) { return upper }
        return nil
    }

    /// True when `pattern` indicates distribution reaching `stateAbbrev`.
    public static func coversState(_ pattern: String?, stateAbbrev: String) -> Bool {
        guard let pattern, !pattern.isEmpty else { return false }

        // Nationwide / multi-region-wide phrasing covers every state.
        let nationwidePhrases = ["nationwide", "nation-wide", "all 50 states", "all states", "u.s. wide", "us wide"]
        if nationwidePhrases.contains(where: pattern.lowercased().contains) { return true }

        let target = stateAbbrev.uppercased()
        guard let fullName = abbreviations.first(where: { $0.value == target })?.key else { return false }

        // Tokenize the RAW (case-preserved) text. State abbreviations appear
        // as all-caps tokens ("CA, OR, in NY"), while the English
        // words "in"/"or"/"me"/"id" are lowercase — so we must NOT uppercase
        // everything first or a user in Indiana matches every line containing
        // the word "in". Full state names are matched case-insensitively.
        for token in pattern.split(whereSeparator: { !($0.isLetter || $0.isNumber) }) {
            if token.lowercased() == fullName { return true } // "...California..."
            if token.uppercased() == target,   // an all-caps abbreviation token
               token == token.uppercased(),
               token.count == 2 {
                return true
            }
        }
        return false
    }
}
