import Foundation

/// Looks up a user-facing string. Keys are the English text itself, so a build without
/// translations (for example `swift run`) simply shows English, and the bundled app shows
/// whatever `Resources/<language>.lproj/Localizable.strings` provides.
///
/// SwiftUI views localize their string literals the same way on their own; this is for
/// strings built in code (menus, model titles, formatted text).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
