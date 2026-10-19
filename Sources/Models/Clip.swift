import Foundation

/// The kind of content a clip holds.
enum ClipKind: String, Codable {
    case text, link, image, files
}

/// One recorded pasteboard entry together with the app it was copied from.
struct Clip: Codable, Identifiable, Equatable {
    var id = UUID()
    var kind: ClipKind
    var text: String?
    var imageFile: String?
    var appName: String
    var bundleID: String?
    var date: Date
    var isFavorite = false
    var label: String?
    var truncated = false

    /// Key used to group clips by source app; clips without a bundle id go under Unknown.
    var appKey: String { bundleID ?? ClipStore.unknownKey }

    /// Single-line-ish text shown in the list.
    var preview: String {
        switch kind {
        case .image: return "Image"
        default:
            let t = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return String(t.prefix(300))
        }
    }

    /// Whether `other` holds the same payload (used to merge identical consecutive copies).
    func sameContent(as other: Clip) -> Bool {
        kind == other.kind && text == other.text && kind != .image
    }
}

/// A source application and how many clips it contributed.
struct AppGroup: Identifiable {
    let key: String
    let name: String
    let count: Int
    let latest: Date
    var id: String { key }
}
