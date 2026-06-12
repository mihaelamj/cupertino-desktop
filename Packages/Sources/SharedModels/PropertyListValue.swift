import Foundation

public enum PropertyListValue: Equatable, Sendable {
    case string(String)
    case boolean(Bool)
    case integer(Int)
    case real(Double)
    case array([PropertyListValue])
    case dictionary([String: PropertyListValue])

    public func toFoundation() -> Any {
        switch self {
        case let .string(s): return s
        case let .boolean(b): return b
        case let .integer(i): return i
        case let .real(d): return d
        case let .array(arr): return arr.map { $0.toFoundation() }
        case let .dictionary(dict):
            var fd: [String: Any] = [:]
            for (k, v) in dict {
                fd[k] = v.toFoundation()
            }
            return fd
        }
    }

    public static func fromFoundation(_ obj: Any) -> PropertyListValue {
        if let s = obj as? String {
            return .string(s)
        }
        #if os(macOS) || os(iOS)
            if CFGetTypeID(obj as CFTypeRef) == CFBooleanGetTypeID() {
                return .boolean(obj as! Bool)
            }
        #else
            if let b = obj as? Bool, type(of: obj) == Bool.self {
                return .boolean(b)
            }
        #endif

        // A floating-point NSNumber must be detected BEFORE the Int bridge: an integral double (3.0)
        // bridges to Int successfully, which would silently retype <real>3</real> as <integer>3</integer>,
        // and a fractional one (3.14) would fall through to the truncating intValue fallback below.
        #if os(macOS) || os(iOS)
            if CFGetTypeID(obj as CFTypeRef) == CFNumberGetTypeID(), CFNumberIsFloatType((obj as! CFNumber)) {
                return .real((obj as! NSNumber).doubleValue)
            }
        #else
            if let d = obj as? Double, type(of: obj) == Double.self {
                return .real(d)
            }
        #endif

        if let i = obj as? Int {
            return .integer(i)
        } else if let arr = obj as? [Any] {
            return .array(arr.map { fromFoundation($0) })
        } else if let dict = obj as? [String: Any] {
            var d: [String: PropertyListValue] = [:]
            for (k, v) in dict {
                d[k] = fromFoundation(v)
            }
            return .dictionary(d)
        } else if let num = obj as? NSNumber {
            // Fallback for NSNumber handling
            let objType = String(cString: num.objCType)
            if objType == "c" || objType == "B" {
                return .boolean(num.boolValue)
            } else if objType == "d" || objType == "f" {
                return .real(num.doubleValue)
            } else {
                return .integer(num.intValue)
            }
        }
        return .string(String(describing: obj))
    }
}

public extension PropertyListValue {
    var stringValue: String? {
        if case let .string(s) = self { return s }
        return nil
    }

    var boolValue: Bool? {
        if case let .boolean(b) = self { return b }
        return nil
    }

    var intValue: Int? {
        if case let .integer(i) = self { return i }
        return nil
    }

    var arrayValue: [PropertyListValue]? {
        if case let .array(a) = self { return a }
        return nil
    }

    var dictionaryValue: [String: PropertyListValue]? {
        if case let .dictionary(d) = self { return d }
        return nil
    }
}
