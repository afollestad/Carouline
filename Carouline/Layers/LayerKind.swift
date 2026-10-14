//
//  LayerKind.swift
//  Carouline
//

/// What a layer is: text or a picture. Every place that adds, lists or edits layers names and
/// draws a kind the same way.
enum LayerKind: CaseIterable, Hashable {
    case text
    case image

    init(of layer: Layer) {
        switch layer.content {
        case .text: self = .text
        case .image: self = .image
        }
    }

    var name: String {
        switch self {
        case .text: "Text"
        case .image: "Image"
        }
    }

    var systemImage: String {
        switch self {
        case .text: "textformat"
        case .image: "photo"
        }
    }

    /// What its editor changes, as the layer bar's Edit button tells VoiceOver.
    var editHint: String {
        switch self {
        case .text: "Edits the layer's words, typeface and style"
        case .image: "Edits the picture's border and blur"
        }
    }

    /// What adding one does, as the add page's tile says it.
    var summary: String {
        switch self {
        case .text: "Words over the slide"
        case .image: "A picture over the slide"
        }
    }
}
