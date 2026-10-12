import Foundation
import ScopedUserDefaults

@Defaults
struct ExplorerDefaults {
    var lastField: String?
    var lastValue: String?
}

@Defaults
struct SearchDefaults {
    var savedField: String?
    var savedValue: String?
}
