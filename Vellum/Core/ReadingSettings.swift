import SwiftUI

enum ReadingFont: String, CaseIterable {
    case system = "System"
    case georgia = "Georgia"
    case palatino = "Palatino"
    case times = "Times New Roman"
    case baskerville = "Baskerville"
    case charter = "Charter"
    case literata = "Literata"
    case openDyslexic = "OpenDyslexic"
    
    var fontName: String? {
        switch self {
        case .system: return nil
        case .georgia: return "Georgia"
        case .palatino: return "Palatino"
        case .times: return "Times New Roman"
        case .baskerville: return "Baskerville"
        case .charter: return "Charter"
        case .literata: return "Literata"
        case .openDyslexic: return "OpenDyslexic"
        }
    }
    
    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName = fontName {
            return .custom(fontName, size: size)
        }
        return .system(size: size, weight: weight)
    }
}

enum PageTheme: String, CaseIterable {
    case light = "Light"
    case sepia = "Sepia"
    case dark = "Dark"
    case black = "Black"
    
    var backgroundColor: Color {
        switch self {
        case .light: return Color(red: 1.0, green: 1.0, blue: 1.0)
        case .sepia: return Color(red: 0.98, green: 0.96, blue: 0.90)
        case .dark: return Color(red: 0.18, green: 0.18, blue: 0.20)
        case .black: return Color(red: 0.0, green: 0.0, blue: 0.0)
        }
    }
    
    var textColor: Color {
        switch self {
        case .light: return Color(red: 0.15, green: 0.15, blue: 0.15)
        case .sepia: return Color(red: 0.30, green: 0.25, blue: 0.20)
        case .dark: return Color(red: 0.85, green: 0.85, blue: 0.85)
        case .black: return Color(red: 0.80, green: 0.80, blue: 0.80)
        }
    }
}

enum LineSpacing: String, CaseIterable {
    case tight = "Tight"
    case normal = "Normal"
    case relaxed = "Relaxed"
    case loose = "Loose"
    
    var multiplier: CGFloat {
        switch self {
        case .tight: return 1.2
        case .normal: return 1.5
        case .relaxed: return 1.8
        case .loose: return 2.2
        }
    }
}

enum TextAlignment: String, CaseIterable {
    case left = "Left"
    case justified = "Justified"
    case center = "Center"
    
    var swiftUIAlignment: SwiftUI.TextAlignment {
        switch self {
        case .left: return .leading
        case .justified: return .leading
        case .center: return .center
        }
    }
}

class ReadingSettings: ObservableObject {
    static let shared = ReadingSettings()
    
    // Font Settings
    @AppStorage("readingFont") private var readingFontRaw: String = ReadingFont.georgia.rawValue
    @AppStorage("fontSize") var fontSize: Double = 18.0
    @AppStorage("fontWeight") private var fontWeightRaw: Int = 0
    
    // Layout Settings
    @AppStorage("lineSpacing") private var lineSpacingRaw: String = LineSpacing.normal.rawValue
    @AppStorage("textAlignment") private var textAlignmentRaw: String = TextAlignment.left.rawValue
    @AppStorage("marginSize") var marginSize: Double = 20.0
    @AppStorage("paragraphSpacing") var paragraphSpacing: Double = 12.0
    
    // Theme Settings
    @AppStorage("pageTheme") private var pageThemeRaw: String = PageTheme.sepia.rawValue
    @AppStorage("autoBrightness") var autoBrightness: Bool = false
    @AppStorage("brightness") var brightness: Double = 0.8
    
    // Reading Experience
    @AppStorage("keepScreenAwake") var keepScreenAwake: Bool = true
    @AppStorage("showProgressBar") var showProgressBar: Bool = true
    @AppStorage("showPageNumbers") var showPageNumbers: Bool = true
    @AppStorage("tapToTurn") var tapToTurn: Bool = true
    @AppStorage("scrollMode") var scrollMode: Bool = false
    
    // Advanced
    @AppStorage("hyphenation") var hyphenation: Bool = true
    @AppStorage("smartQuotes") var smartQuotes: Bool = true
    
    var readingFont: ReadingFont {
        get { ReadingFont(rawValue: readingFontRaw) ?? .georgia }
        set {
            readingFontRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var lineSpacing: LineSpacing {
        get { LineSpacing(rawValue: lineSpacingRaw) ?? .normal }
        set {
            lineSpacingRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var textAlignment: TextAlignment {
        get { TextAlignment(rawValue: textAlignmentRaw) ?? .left }
        set {
            textAlignmentRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var pageTheme: PageTheme {
        get { PageTheme(rawValue: pageThemeRaw) ?? .sepia }
        set {
            pageThemeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var fontWeight: Font.Weight {
        get {
            switch fontWeightRaw {
            case -1: return .light
            case 0: return .regular
            case 1: return .medium
            case 2: return .semibold
            default: return .regular
            }
        }
        set {
            switch newValue {
            case .light: fontWeightRaw = -1
            case .regular: fontWeightRaw = 0
            case .medium: fontWeightRaw = 1
            case .semibold: fontWeightRaw = 2
            default: fontWeightRaw = 0
            }
            objectWillChange.send()
        }
    }
    
    func currentFont() -> Font {
        readingFont.font(size: fontSize, weight: fontWeight)
    }
    
    func resetToDefaults() {
        readingFontRaw = ReadingFont.georgia.rawValue
        fontSize = 18.0
        fontWeightRaw = 0
        lineSpacingRaw = LineSpacing.normal.rawValue
        textAlignmentRaw = TextAlignment.left.rawValue
        marginSize = 20.0
        paragraphSpacing = 12.0
        pageThemeRaw = PageTheme.sepia.rawValue
        autoBrightness = false
        brightness = 0.8
        keepScreenAwake = true
        showProgressBar = true
        showPageNumbers = true
        tapToTurn = true
        scrollMode = false
        hyphenation = true
        smartQuotes = true
        objectWillChange.send()
    }
    
    private init() {}
}
