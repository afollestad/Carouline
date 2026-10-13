//
//  SlideLayout.swift
//  Swipeset
//

/// How a slide splits into cells, or, as a panorama, one cell cut across several slides.
nonisolated enum SlideLayout: String, Codable, CaseIterable, Identifiable, Sendable {
    case single
    case twoColumns
    case twoRows
    case twoTopOneBottom
    case oneTopTwoBottom
    case oneLeftTwoRight
    case twoLeftOneRight
    case threeColumns
    case threeRows
    case grid
    case panorama

    var id: Self { self }

    var name: String {
        switch self {
        case .single: "Single"
        case .twoColumns: "Split Vertically"
        case .twoRows: "Split Horizontally"
        case .twoTopOneBottom: "Two Top, One Bottom"
        case .oneTopTwoBottom: "One Top, Two Bottom"
        case .oneLeftTwoRight: "One Left, Two Right"
        case .twoLeftOneRight: "Two Left, One Right"
        case .threeColumns: "Three Columns"
        case .threeRows: "Three Rows"
        case .grid: "Grid of Four"
        case .panorama: "Panorama"
        }
    }

    var grid: LayoutGrid {
        switch self {
        case .single, .panorama:
            LayoutGrid(columns: 1, rows: 1, cells: [.init(0, 0)])
        case .twoColumns:
            LayoutGrid(columns: 2, rows: 1, cells: [.init(0, 0), .init(1, 0)])
        case .twoRows:
            LayoutGrid(columns: 1, rows: 2, cells: [.init(0, 0), .init(0, 1)])
        case .twoTopOneBottom:
            LayoutGrid(columns: 2, rows: 2, cells: [.init(0, 0), .init(1, 0), .init(0, 1, columnSpan: 2)])
        case .oneTopTwoBottom:
            LayoutGrid(columns: 2, rows: 2, cells: [.init(0, 0, columnSpan: 2), .init(0, 1), .init(1, 1)])
        case .oneLeftTwoRight:
            LayoutGrid(columns: 2, rows: 2, cells: [.init(0, 0, rowSpan: 2), .init(1, 0), .init(1, 1)])
        case .twoLeftOneRight:
            LayoutGrid(columns: 2, rows: 2, cells: [.init(0, 0), .init(1, 0, rowSpan: 2), .init(0, 1)])
        case .threeColumns:
            LayoutGrid(columns: 3, rows: 1, cells: [.init(0, 0), .init(1, 0), .init(2, 0)])
        case .threeRows:
            LayoutGrid(columns: 1, rows: 3, cells: [.init(0, 0), .init(0, 1), .init(0, 2)])
        case .grid:
            LayoutGrid(columns: 2, rows: 2, cells: [.init(0, 0), .init(1, 0), .init(0, 1), .init(1, 1)])
        }
    }
}

/// A layout as whole grid tracks, so its cells tile a slide exactly, with no thirds left over
/// to round, and every gap between them comes out the same width.
nonisolated struct LayoutGrid: Hashable, Sendable {
    /// A cell's place in the grid. Cells are listed in reading order, by their top-left track.
    struct Span: Hashable, Sendable {
        let column: Int
        let row: Int
        let columnSpan: Int
        let rowSpan: Int

        init(_ column: Int, _ row: Int, columnSpan: Int = 1, rowSpan: Int = 1) {
            self.column = column
            self.row = row
            self.columnSpan = columnSpan
            self.rowSpan = rowSpan
        }
    }

    let columns: Int
    let rows: Int
    let cells: [Span]
}
