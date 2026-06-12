import Foundation
import SharedModels

#if !os(WASI)
    public class PackManager {
        public static func isBinary(path: String) -> Bool {
            let binaryExtensions = [
                ".png", ".jpg", ".jpeg", ".pdf", ".tiff", ".gif",
                ".zip", ".tar", ".gz", ".car", ".appiconset", ".imageset",
            ]
            let ext = (path as NSString).pathExtension.lowercased()
            return binaryExtensions.contains("." + ext)
        }

        public static func packFolder(path: String) throws -> XcodeTemplateBundle {
            let fileManager = FileManager.default
            // Resolve symlinks so relative paths compute correctly (on macOS /tmp is a symlink to /private/tmp,
            // and the enumerator returns resolved paths; an unresolved root would leave the keys absolute).
            let folderURL = URL(fileURLWithPath: path).resolvingSymlinksInPath()
            let templateName = folderURL.lastPathComponent
            let plistURL = folderURL.appendingPathComponent("TemplateInfo.plist")

            if !fileManager.fileExists(atPath: plistURL.path) {
                throw NSError(domain: "PackerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing TemplateInfo.plist inside \(path)"])
            }

            // 1. Load plist metadata
            let plistData = try Data(contentsOf: plistURL)
            var format = PropertyListSerialization.PropertyListFormat.xml
            let plistObj = try PropertyListSerialization.propertyList(from: plistData, options: [], format: &format)

            let metadata = PropertyListValue.fromFoundation(plistObj)
            let templateId = (plistObj as? [String: Any])?["Identifier"] as? String ?? ""

            var bundle = XcodeTemplateBundle(name: templateName, identifier: templateId, metadata: [:], files: [:])
            if case let .dictionary(dict) = metadata {
                bundle.metadata = dict
            }

            // 2. Scan all files
            let enumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isRegularFileKey], options: []) { _, _ in true }

            while let fileURL = enumerator?.nextObject() as? URL {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: fileURL.path, isDirectory: &isDir), !isDir.boolValue else {
                    continue
                }
                // Resolve the entry the same way as the root, so the prefix strip works under symlinked
                // roots (the enumerator yields /private/tmp/... even when given /tmp/...).
                let relativePath = fileURL.resolvingSymlinksInPath().path.replacingOccurrences(of: folderURL.path + "/", with: "")
                if relativePath == "TemplateInfo.plist" { continue }
                if fileURL.lastPathComponent == ".DS_Store" { continue }

                let isBinary = isBinary(path: fileURL.path)

                if isBinary {
                    let fileData = try Data(contentsOf: fileURL)
                    let base64Content = fileData.base64EncodedString()
                    bundle.files[relativePath] = FileInfo(type: "binary", content: base64Content)
                } else {
                    do {
                        let textContent = try String(contentsOf: fileURL, encoding: .utf8)
                        bundle.files[relativePath] = FileInfo(type: "text", content: textContent)
                    } catch {
                        // Fallback to binary if UTF8 decoding fails
                        let fileData = try Data(contentsOf: fileURL)
                        let base64Content = fileData.base64EncodedString()
                        bundle.files[relativePath] = FileInfo(type: "binary", content: base64Content)
                    }
                }
            }

            // Record directories that contain no files, so empty folders (e.g. an empty Media.xcassets) survive
            // the round-trip. A directory is empty when no packed file lives anywhere beneath it.
            let dirEnumerator = fileManager.enumerator(at: folderURL, includingPropertiesForKeys: [.isDirectoryKey], options: []) { _, _ in true }
            while let dirURL = dirEnumerator?.nextObject() as? URL {
                var isDir: ObjCBool = false
                guard fileManager.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else { continue }
                let relativeDir = dirURL.resolvingSymlinksInPath().path.replacingOccurrences(of: folderURL.path + "/", with: "")
                if relativeDir.isEmpty { continue }
                let prefix = relativeDir + "/"
                if !bundle.files.keys.contains(where: { $0.hasPrefix(prefix) }) {
                    bundle.emptyDirectories.append(relativeDir)
                }
            }

            return bundle
        }

        public static func unpackBundle(_ bundle: XcodeTemplateBundle, toParentFolder parentPath: String) throws {
            let fileManager = FileManager.default
            let templateDir = URL(fileURLWithPath: parentPath).appendingPathComponent(bundle.name)

            if fileManager.fileExists(atPath: templateDir.path) {
                try fileManager.removeItem(at: templateDir)
            }
            try fileManager.createDirectory(at: templateDir, withIntermediateDirectories: true, attributes: nil)

            // 1. Recreate TemplateInfo.plist
            let plistURL = templateDir.appendingPathComponent("TemplateInfo.plist")
            var plistObj: [String: Any] = [:]
            for (k, v) in bundle.metadata {
                plistObj[k] = v.toFoundation()
            }
            if !bundle.identifier.isEmpty {
                plistObj["Identifier"] = bundle.identifier
            }
            let plistData = try PropertyListSerialization.data(fromPropertyList: plistObj, format: .xml, options: 0)
            try plistData.write(to: plistURL)

            // 2. Recreate template files
            for (relPath, fileInfo) in bundle.files {
                let destURL = templateDir.appendingPathComponent(relPath)
                try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)

                if fileInfo.type == "binary" {
                    if let fileData = Data(base64Encoded: fileInfo.content) {
                        try fileData.write(to: destURL)
                    } else {
                        // Skipping would silently produce an incomplete bundle; fail loudly instead.
                        throw NSError(domain: "PackerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Binary content for \(relPath) is not valid base64"])
                    }
                } else {
                    try fileInfo.content.write(to: destURL, atomically: true, encoding: .utf8)
                }
            }

            // 3. Recreate empty directories (those with no files to imply them).
            for relativeDir in bundle.emptyDirectories {
                let dirURL = templateDir.appendingPathComponent(relativeDir)
                try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true, attributes: nil)
            }
            // No success print: this is a library; the caller (CLI or IDE) owns user-facing output.
        }
    }
#endif
