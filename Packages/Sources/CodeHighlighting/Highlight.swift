/// Code highlighting concrete: a `Model.CodeHighlighting` backed by Splash. Kept in its
/// own package so the highlighting library is this concrete's single external dependency
/// and the markdown renderer reaches it only through the `Model.CodeHighlighting` seam.
public enum Highlight {}
