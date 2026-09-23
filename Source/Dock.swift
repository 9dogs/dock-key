import Foundation

struct DockApp: Identifiable, Equatable {
    var id: String { url.absoluteString }
    let url: URL
    let name: String
}

enum DockReader {
    static func parse(_ tiles: [[String: Any]]) -> [DockApp] {
        var seen = Set<String>()
        return tiles.compactMap { tile in
            guard tile["tile-type"] as? String == "file-tile",
                  let data = tile["tile-data"] as? [String: Any],
                  data["bundle-identifier"] as? String != "com.apple.finder",
                  let file = data["file-data"] as? [String: Any],
                  let path = file["_CFURLString"] as? String,
                  let url = URL(string: path), url.isFileURL,
                  url.pathExtension.lowercased() == "app",
                  seen.insert(url.standardizedFileURL.path).inserted else { return nil }
            return DockApp(url: url, name: data["file-label"] as? String ?? url.deletingPathExtension().lastPathComponent)
        }
    }
    static func read() throws -> [DockApp] {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences/com.apple.dock.plist")
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        guard let dictionary = plist as? [String: Any], let tiles = dictionary["persistent-apps"] as? [[String: Any]] else {
            throw NSError(domain: "DockKey", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not read the Dock’s pinned applications."])
        }
        return parse(tiles)
    }
}
