import Foundation

public indirect enum SemanticNode: Sendable, Hashable {
    case screen(title: String, children: [Self])
    case collection(title: String?, children: [Self])
    case entity(id: String, title: String, facts: [String], traits: Set<SemanticTrait>)
    case insight(id: String, title: String, value: String, scope: String)
    case command(id: String, title: String, role: SemanticRole = .normal)
    case status(String)
}

public enum SemanticTrait: String, Sendable, Hashable { case liked, pending, aggregate, local }
public enum SemanticRole: String, Sendable, Hashable { case normal, primary, destructive }
