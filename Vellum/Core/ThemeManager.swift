import SwiftUI

enum AppTheme: String, CaseIterable {
    case sepia = "Sepia"
    case midnight = "Midnight"
    case ocean = "Ocean"
    case forest = "Forest"
    case lavender = "Lavender"
    
    var color: Color {
        switch self {
        case .sepia:
            return Color(red: 0.55, green: 0.40, blue: 0.30)
        case .midnight:
            return Color(red: 0.20, green: 0.25, blue: 0.35)
        case .ocean:
            return Color(red: 0.20, green: 0.50, blue: 0.60)
        case .forest:
            return Color(red: 0.25, green: 0.45, blue: 0.35)
        case .lavender:
            return Color(red: 0.55, green: 0.45, blue: 0.65)
        }
    }
    
    var gradientColors: [Color] {
        switch self {
        case .sepia:
            return [Color(red: 0.60, green: 0.45, blue: 0.35),
                    Color(red: 0.45, green: 0.30, blue: 0.20)]
        case .midnight:
            return [Color(red: 0.25, green: 0.30, blue: 0.45),
                    Color(red: 0.15, green: 0.18, blue: 0.28)]
        case .ocean:
            return [Color(red: 0.25, green: 0.55, blue: 0.70),
                    Color(red: 0.15, green: 0.40, blue: 0.55)]
        case .forest:
            return [Color(red: 0.30, green: 0.50, blue: 0.40),
                    Color(red: 0.18, green: 0.35, blue: 0.28)]
        case .lavender:
            return [Color(red: 0.60, green: 0.50, blue: 0.70),
                    Color(red: 0.45, green: 0.38, blue: 0.55)]
        }
    }
}

class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @AppStorage("selectedTheme") private var selectedThemeRaw: String = AppTheme.sepia.rawValue
    
    var currentTheme: AppTheme {
        get { AppTheme(rawValue: selectedThemeRaw) ?? .sepia }
        set {
            selectedThemeRaw = newValue.rawValue
            objectWillChange.send()
        }
    }
    
    var accentColor: Color {
        currentTheme.color
    }
    
    var gradientColors: [Color] {
        currentTheme.gradientColors
    }
    
    private init() {}
}

struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .sepia
}

extension EnvironmentValues {
    var appTheme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func themed() -> some View {
        self.tint(ThemeManager.shared.accentColor)
    }
}
