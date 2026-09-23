import Foundation
func tile(_ name: String, _ path: String, bundle: String = "test.app") -> [String: Any] {
    ["tile-type": "file-tile", "tile-data": ["file-label": name, "bundle-identifier": bundle, "file-data": ["_CFURLString": path]]]
}
let fixtures: [[String: Any]] = [
    tile("Finder", "file:///System/Library/CoreServices/Finder.app/", bundle: "com.apple.finder"),
    tile("Terminal", "file:///System/Applications/Utilities/Terminal.app/"),
    ["tile-type": "spacer-tile"],
    tile("PyCharm", "file:///Applications/PyCharm.app/"),
    tile("Text App", "file:///Applications/Text%20App.app/"),
    tile("Document", "file:///tmp/doc.pdf"),
    tile("Remote", "https://example.com/Fake.app"),
    tile("Duplicate", "file:///Applications/PyCharm.app/"),
    ["tile-type": "file-tile"]
]
let apps = DockReader.parse(fixtures)
precondition(apps.map(\.name) == ["Terminal", "PyCharm", "Text App"])
precondition(apps[2].url.path == "/Applications/Text App.app")
precondition(DockReader.parse([]).isEmpty)
precondition(DockReader.parse(Array(fixtures.reversed())).map(\.name) == ["Duplicate", "Text App", "Terminal"])
print("PASS: order, Finder exclusion, spacers, invalid entries, file URL filtering, percent encoding, duplicates, empty Dock and reordered Dock")
