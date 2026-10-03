import Foundation
import StateBlasterPresentationParser

func swiftSource() -> String {
    #"""
    #if canImport(UIKit)
    import UIKit
    import OnboardingShared

    @MainActor public final class OnboardingContainerViewController: UIViewController {
        private var current: UIViewController?
        public func show(_ screen: OnboardingStateMachine.Screen, seed: UInt64 = 32) {
            let next = OnboardingSceneViewController(screen: screen, seed: seed)
            if let current {
                current.willMove(toParent: nil)
                current.view.removeFromSuperview()
                current.removeFromParent()
            }
            addChild(next)
            view.addSubview(next.view)
            next.view.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                next.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
                next.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
                next.view.topAnchor.constraint(equalTo: view.topAnchor),
                next.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            ])
            next.didMove(toParent: self)
            current = next
        }
    }

    @MainActor public final class OnboardingSceneViewController: UIViewController {
        private let screen: OnboardingStateMachine.Screen
        private let seed: UInt64
        public init(screen: OnboardingStateMachine.Screen, seed: UInt64 = 32) {
            self.screen = screen
            self.seed = seed
            super.init(nibName: nil, bundle: nil)
        }
        required init?(coder: NSCoder) {
            screen = .initializing
            seed = 32
            super.init(coder: coder)
        }
        public override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .systemBackground
            let descriptor = OnboardingStateMachine.screens.first { $0.state == screen }!
            let title = UILabel()
            title.text = descriptor.title
            title.font = .preferredFont(forTextStyle: .largeTitle)
            title.numberOfLines = 0
            let message = UILabel()
            message.text = descriptor.message
            message.textColor = .secondaryLabel
            message.numberOfLines = 0
            let stack = UIStackView(arrangedSubviews: [title, message])
            stack.axis = .vertical
            stack.spacing = 18
            stack.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(stack)
            NSLayoutConstraint.activate([
                stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
                stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            ])
        }
    }
    #endif
    """#
}

func ibID(_ state: String, _ role: String) -> String {
    let bytes = Array("\(state):\(role)".utf8)
    var hash: UInt64 = 1_469_598_103_934_665_603
    for byte in bytes {
        hash ^= UInt64(byte)
        hash &*= 1_099_511_628_211
    }
    let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789")
    var value = hash
    var result = ""
    for _ in 0..<10 {
        result.append(alphabet[Int(value % UInt64(alphabet.count))])
        value /= UInt64(alphabet.count)
    }
    return result
}

struct XMLNode {
    var name: String
    var attributes: [String: String] = [:]
    var children: [XMLNode] = []

    func rendered(indentation: Int = 0) -> String {
        let indent = String(repeating: "    ", count: indentation)
        let attributesText =
            attributes
            .sorted { $0.key < $1.key }
            .map { " \($0.key)=\"\(Self.escape($0.value, attribute: true))\"" }
            .joined()

        guard !children.isEmpty else {
            return "\(indent)<\(name)\(attributesText)/>"
        }

        let body =
            children
            .map { $0.rendered(indentation: indentation + 1) }
            .joined(separator: "\n")
        return "\(indent)<\(name)\(attributesText)>\n\(body)\n\(indent)</\(name)>"
    }

    private static func escape(_ value: String, attribute: Bool) -> String {
        var result =
            value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        if attribute {
            result =
                result
                .replacingOccurrences(of: "\"", with: "&quot;")
                .replacingOccurrences(of: "'", with: "&apos;")
        }
        return result
    }
}

func node(_ name: String, _ attributes: [String: String] = [:], _ children: [XMLNode] = []) -> XMLNode {
    XMLNode(name: name, attributes: attributes, children: children)
}

func storyboard(states: [PresentationStateDescription]) throws -> String {
    guard let initial = states.first else {
        throw CocoaError(.fileWriteUnknown)
    }

    let scenes = states.enumerated().map { index, state in
        node(
            "scene",
            ["sceneID": ibID(state.name, "scene")],
            [
                node(
                    "objects",
                    [:],
                    [
                        node(
                            "viewController",
                            [
                                "storyboardIdentifier": state.name,
                                "id": ibID(state.name, "viewController"),
                                "customClass": "OnboardingSceneViewController",
                                "customModule": "OnboardingUIKitApp",
                                "sceneMemberID": "viewController",
                            ],
                            [
                                node(
                                    "view",
                                    [
                                        "key": "view",
                                        "contentMode": "scaleToFill",
                                        "id": ibID(state.name, "view"),
                                    ],
                                    [
                                        node(
                                            "rect",
                                            [
                                                "key": "frame", "x": "0.0", "y": "0.0", "width": "393", "height": "852",
                                            ]
                                        ),
                                        node(
                                            "viewLayoutGuide",
                                            [
                                                "key": "safeArea", "id": ibID(state.name, "safeArea"),
                                            ]
                                        ),
                                        node(
                                            "color",
                                            [
                                                "key": "backgroundColor", "systemColor": "systemBackgroundColor",
                                            ]
                                        ),
                                    ]
                                )
                            ]
                        ),
                        node(
                            "placeholder",
                            [
                                "placeholderIdentifier": "IBFirstResponder",
                                "id": ibID(state.name, "firstResponder"),
                                "sceneMemberID": "firstResponder",
                            ]
                        ),
                    ]
                ),
                node(
                    "point",
                    [
                        "key": "canvasLocation", "x": String(120 + index * 520), "y": "120",
                    ]
                ),
            ]
        )
    }

    let document = node(
        "document",
        [
            "type": "com.apple.InterfaceBuilder3.CocoaTouch.Storyboard.XIB",
            "version": "3.0",
            "toolsVersion": "23094",
            "targetRuntime": "iOS.CocoaTouch",
            "propertyAccessControl": "none",
            "useAutolayout": "YES",
            "useTraitCollections": "YES",
            "useSafeAreas": "YES",
            "colorMatched": "YES",
            "initialViewController": ibID(initial.name, "viewController"),
        ],
        [
            node("device", ["id": "retina6_12", "orientation": "portrait", "appearance": "light"]),
            node(
                "dependencies",
                [:],
                [
                    node("deployment", ["identifier": "iOS"]),
                    node(
                        "plugIn",
                        [
                            "identifier": "com.apple.InterfaceBuilder.IBCocoaTouchPlugin", "version": "23084",
                        ]
                    ),
                    node("capability", ["name": "Safe area layout guides", "minToolsVersion": "9.0"]),
                    node("capability", ["name": "System colors in document resources", "minToolsVersion": "11.0"]),
                    node("capability", ["name": "documents saved in the Xcode 8 format", "minToolsVersion": "8.0"]),
                ]
            ),
            node("scenes", [:], scenes),
            node(
                "resources",
                [:],
                [
                    node(
                        "systemColor",
                        ["name": "systemBackgroundColor"],
                        [
                            node(
                                "color",
                                [
                                    "white": "1", "alpha": "1", "colorSpace": "custom",
                                    "customColorSpace": "genericGamma22GrayColorSpace",
                                ]
                            )
                        ]
                    )
                ]
            ),
        ]
    )

    return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + document.rendered() + "\n"
}

let args = CommandLine.arguments
precondition(
    args.count >= 5,
    "usage: StateBlasterStoryboardGenerator <target-name> <generated-swift> <generated-storyboard> <source> [<source> ...]"
)

let targetName = args[1]
let generatedSwift = URL(fileURLWithPath: args[2])
let generatedStoryboard = URL(fileURLWithPath: args[3])
let sourceURLs = args.dropFirst(4).map { URL(fileURLWithPath: $0) }

var matches: [(url: URL, states: [PresentationStateDescription])] = []
for sourceURL in sourceURLs {
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let states = try StateBlasterPresentationParser.parse(source)
    if !states.isEmpty {
        matches.append((sourceURL, states))
    }
}

guard let match = matches.first else {
    fatalError()
}
guard matches.count == 1 else {
    fatalError()
}

try FileManager.default.createDirectory(
    at: generatedSwift.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try FileManager.default.createDirectory(
    at: generatedStoryboard.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try swiftSource().write(
    to: generatedSwift,
    atomically: true,
    encoding: .utf8
)
try storyboard(states: match.states).write(
    to: generatedStoryboard,
    atomically: true,
    encoding: .utf8
)
