import Foundation

/// Compiler-emitted help metadata: the namespace for everything the engine knows ABOUT the
/// language and the template vocabulary, positioned so an IDE can show it as hover help.
///
/// The IDE never hardcodes template knowledge (it is template-agnostic); instead the engine walks
/// a source and emits one `Documentation.Entry` per thing the user could point at: construct
/// keywords, manifest keys in `let` bindings, macros inside string values, option `Type` values.
/// The knowledge base is `Documentation.Catalog`, corpus-grounded: the doc corpus gate proves that
/// every key and macro occurring anywhere in the 10,117-template corpus has an entry.
public enum Documentation {}
