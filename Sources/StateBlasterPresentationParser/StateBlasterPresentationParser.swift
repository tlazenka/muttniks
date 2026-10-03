import Foundation

public struct PresentationStateDescription: Sendable, Equatable {
    public let name: String
    public let title: String
    public let message: String
    public init(name: String, title: String, message: String) {
        self.name = name; self.title = title; self.message = message
    }
}

public enum StateBlasterPresentationParser {
    private static func capture(_ pattern: String, in text: String, group: Int = 1) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators]),
            let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
            let range = Range(match.range(at: group), in: text)
        else { return nil }
        return String(text[range])
    }

    public static func parse(_ source: String) throws -> [PresentationStateDescription] {
        let pattern = #"@MachineState(?:\((.*?)\))?\s*@Screen\((.*?)\)\s*case\s+(\w+)"#
        let regex = try NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
        return try regex.matches(in: source, range: NSRange(source.startIndex..., in: source)).map { match in
            func group(_ i: Int) -> String {
                guard let r = Range(match.range(at: i), in: source) else { return "" }
                return String(source[r])
            }
            let screen = group(2)
            guard let title = capture(#"title:\s*\"([^\"]*)\""#, in: screen),
                let message = capture(#"message:\s*\"([^\"]*)\""#, in: screen)
            else {
                throw NSError(
                    domain: "StateBlasterPresentationParser",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "@Screen requires literal title and message"]
                )
            }
            return .init(name: group(3), title: title, message: message)
        }
    }
}
