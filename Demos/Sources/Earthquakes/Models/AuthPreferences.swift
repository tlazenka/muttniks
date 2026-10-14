import Foundation
import ScopedUserDefaults

@Defaults(.named("com.muttniks.earthquakes.auth"))
struct AuthDefaults {
    var token: String?
}
