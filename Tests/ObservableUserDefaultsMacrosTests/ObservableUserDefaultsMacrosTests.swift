import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import XCTest

@testable import ObservableUserDefaultsMacros

private let macros: [String: Macro.Type] = ["DefaultKey": DefaultKeyMacro.self]

final class ObservableUserDefaultsMacrosTests: XCTestCase {
    func testBoolUsesPropertyName() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey
                @objc dynamic var shouldCheckAutomatically: Bool
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    @objc dynamic var shouldCheckAutomatically: Bool {
                        get {
                            return bool(forKey: "shouldCheckAutomatically")
                        }
                        set {
                            set(newValue, forKey: "shouldCheckAutomatically")
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testExplicitKey() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey("legacy.auto-check")
                @objc dynamic var shouldCheckAutomatically: Bool
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    @objc dynamic var shouldCheckAutomatically: Bool {
                        get {
                            return bool(forKey: "legacy.auto-check")
                        }
                        set {
                            set(newValue, forKey: "legacy.auto-check")
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testScalarMappings() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var count: Int
                @DefaultKey var interval: Double
                @DefaultKey var ratio: Float
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var count: Int {
                        get {
                            return integer(forKey: "count")
                        }
                        set {
                            set(newValue, forKey: "count")
                        }
                    }
                    var interval: Double {
                        get {
                            return double(forKey: "interval")
                        }
                        set {
                            set(newValue, forKey: "interval")
                        }
                    }
                    var ratio: Float {
                        get {
                            return float(forKey: "ratio")
                        }
                        set {
                            set(newValue, forKey: "ratio")
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testOptionalFoundationMappingsRemoveNil() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var name: String?
                @DefaultKey var blob: Data?
                @DefaultKey var endpoint: URL?
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var name: String? {
                        get {
                            return string(forKey: "name")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "name")
                            } else {
                                removeObject(forKey: "name")
                            }
                        }
                    }
                    var blob: Data? {
                        get {
                            return data(forKey: "blob")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "blob")
                            } else {
                                removeObject(forKey: "blob")
                            }
                        }
                    }
                    var endpoint: URL? {
                        get {
                            return url(forKey: "endpoint")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "endpoint")
                            } else {
                                removeObject(forKey: "endpoint")
                            }
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testCollectionMappings() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var values: [Any]?
                @DefaultKey var metadata: [String: Any]?
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var values: [Any]? {
                        get {
                            return array(forKey: "values")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "values")
                            } else {
                                removeObject(forKey: "values")
                            }
                        }
                    }
                    var metadata: [String: Any]? {
                        get {
                            return dictionary(forKey: "metadata")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "metadata")
                            } else {
                                removeObject(forKey: "metadata")
                            }
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testOptionalSpelling() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var name: Optional<String>
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var name: Optional<String> {
                        get {
                            return string(forKey: "name")
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "name")
                            } else {
                                removeObject(forKey: "name")
                            }
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testDateMapping() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var date: Date?
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var date: Date? {
                        get {
                            return object(forKey: "date") as? Date
                        }
                        set {
                            if let newValue {
                                set(newValue, forKey: "date")
                            } else {
                                removeObject(forKey: "date")
                            }
                        }
                    }
                }
                """,
            macros: macros
        )
    }

    func testRejectsUnsupportedType() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var identifier: UUID?
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var identifier: UUID?
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@DefaultKey does not support type 'UUID?'", line: 2, column: 5)
            ],
            macros: macros
        )
    }

    func testRejectsMissingType() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var value
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var value
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "@DefaultKey can only be attached to one typed property",
                    line: 2,
                    column: 5
                )
            ],
            macros: macros
        )
    }

    func testRejectsInitializer() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var enabled: Bool = true
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var enabled: Bool = true
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@DefaultKey properties cannot have an initializer", line: 2, column: 5)
            ],
            macros: macros
        )
    }

    func testRejectsExistingAccessors() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey var enabled: Bool { false }
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var enabled: Bool { false }
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@DefaultKey properties cannot have an accessorBlock", line: 2, column: 5)
            ],
            macros: macros
        )
    }

    func testRejectsNonLiteralKey() {
        assertMacroExpansion(
            """
            extension UserDefaults {
                @DefaultKey(Self.key) var enabled: Bool
            }
            """,
            expandedSource: """
                extension UserDefaults {
                    var enabled: Bool
                }
                """,
            diagnostics: [
                DiagnosticSpec(message: "@DefaultKey expects a string literal", line: 2, column: 5)
            ],
            macros: macros
        )
    }
}
