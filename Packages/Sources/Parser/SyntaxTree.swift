import Foundation
import Lexer

/// A node of the concrete syntax tree (Dragon Book sections 2.5.1 and 5.3.1): the parser's structural
/// record of the source, with every node carrying the half-open range of tokens it spans. Ranges map
/// back to exact source positions through the token stream (each `Token` carries line and column), which
/// is what editor features need: highlighting, folding, selection, navigation, and precise quick-fixes.
///
/// The tree is concrete and generic (nodes are identified by `kind`) rather than a typed AST: it records
/// what the parser actually consumed, including enough structure for an editor, without freezing a large
/// typed surface this early. The semantic model (`XcodeTemplateBundle`) continues to be derived during
/// the same parse; the tree is a parallel, lossless structural view.
public struct SyntaxNode {
    /// What this node is. The vocabulary is closed and documented here rather than spread over types.
    /// Structural constructs only for now; finer-grained nodes (keys, value expressions) come with the
    /// typed AST layer once the editor needs them.
    public enum Kind: String, Sendable {
        case template // the whole `template "id" { ... }` block
        case letBinding // `let Key = value`
        case option // `option "id" { ... }`
        case unit // `unit "value" { ... }`
        case node // `node "path" { ... }`
        case directory // `directory "path"`
    }

    public let kind: Kind
    /// Half-open range into the parser's token array: `tokens[tokenRange]` is exactly what this node spans.
    public private(set) var tokenRange: Range<Int>
    public private(set) var children: [SyntaxNode]

    public init(kind: Kind, tokenRange: Range<Int>, children: [SyntaxNode] = []) {
        self.kind = kind
        self.tokenRange = tokenRange
        self.children = children
    }

    mutating func extend(to upperBound: Int) {
        tokenRange = tokenRange.lowerBound ..< max(tokenRange.upperBound, upperBound)
    }

    mutating func append(_ child: SyntaxNode) {
        children.append(child)
    }
}

public extension SyntaxNode {
    /// The source range of this node: the position of its first token through the position just past
    /// its last token's lexeme, as RECORDED by the scanner (never estimated from the cooked value,
    /// which goes wrong across escape sequences, raw-string delimiters, and multi-line lexemes).
    /// Line and column are 1-based, matching `SyntaxError`.
    func sourceRange(in tokens: [Token]) -> (startLine: Int, startColumn: Int, endLine: Int, endColumn: Int)? {
        guard !tokenRange.isEmpty, tokenRange.upperBound <= tokens.count else { return nil }
        let first = tokens[tokenRange.lowerBound]
        let last = tokens[tokenRange.upperBound - 1]
        return (first.line, first.column, last.endLine, last.endColumn)
    }

    /// Every node in this subtree, depth-first, paired with its depth. The traversal an editor uses to
    /// build fold ranges and outline views.
    func walk(depth: Int = 0, _ visit: (SyntaxNode, Int) -> Void) {
        visit(self, depth)
        for child in children {
            child.walk(depth: depth + 1, visit)
        }
    }
}
