import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var readingSettings: ReadingSettings
    @ObservedObject private var themeManager = ThemeManager.shared
    
    @State private var showingResetAlert = false
    @State private var showingAbout = false
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Reading Defaults Section
                Section {
                    NavigationLink {
                        FontSettingsView()
                    } label: {
                        HStack {
                            Label("Font", systemImage: "textformat")
                            Spacer()
                            Text(readingSettings.readingFont.rawValue)
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    NavigationLink {
                        LayoutSettingsView()
                    } label: {
                        Label("Layout", systemImage: "text.alignleft")
                    }
                    
                    NavigationLink {
                        PageThemeSettingsView()
                    } label: {
                        HStack {
                            Label("Page Theme", systemImage: "circle.lefthalf.filled")
                            Spacer()
                            RoundedRectangle(cornerRadius: 4)
                                .fill(readingSettings.pageTheme.backgroundColor)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                                .frame(width: 24, height: 18)
                        }
                    }
                } header: {
                    Label("Reading Defaults", systemImage: "book")
                } footer: {
                    Text("These settings will be applied to all new reading sessions.")
                }
                
                // MARK: - Reading Experience Section
                Section {
                    Toggle(isOn: $readingSettings.keepScreenAwake) {
                        Label("Keep Screen Awake", systemImage: "sun.max")
                    }
                    
                    Toggle(isOn: $readingSettings.showProgressBar) {
                        Label("Show Progress Bar", systemImage: "chart.bar.xaxis")
                    }
                    
                    Toggle(isOn: $readingSettings.showPageNumbers) {
                        Label("Show Page Numbers", systemImage: "number")
                    }
                    
                    Toggle(isOn: $readingSettings.tapToTurn) {
                        Label("Tap to Turn Pages", systemImage: "hand.tap")
                    }
                } header: {
                    Label("Reading Experience", systemImage: "sparkles")
                }
                
                // MARK: - Appearance Section
                Section {
                    NavigationLink {
                        ThemePickerView()
                    } label: {
                        HStack {
                            Label("Accent Color", systemImage: "paintbrush")
                            Spacer()
                            Circle()
                                .fill(themeManager.accentColor)
                                .frame(width: 24, height: 24)
                        }
                    }
                } header: {
                    Label("Appearance", systemImage: "paintpalette")
                } footer: {
                    Text("Customize the app's accent color throughout the interface.")
                }
                
                // MARK: - Advanced Section
                Section {
                    Toggle(isOn: $readingSettings.hyphenation) {
                        Label("Hyphenation", systemImage: "minus")
                    }
                    
                    Toggle(isOn: $readingSettings.smartQuotes) {
                        Label("Smart Quotes", systemImage: "quote.opening")
                    }
                } header: {
                    Label("Advanced", systemImage: "gearshape.2")
                } footer: {
                    Text("Hyphenation helps with text flow on narrow margins. Smart quotes convert straight quotes to typographic quotes.")
                }
                
                // MARK: - About Section
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Label("Build", systemImage: "hammer")
                        Spacer()
                        Text(buildNumber)
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Label("About", systemImage: "info.circle")
                }
                
                // MARK: - Reset Section
                Section {
                    Button(role: .destructive) {
                        showingResetAlert = true
                    } label: {
                        HStack {
                            Label("Reset All Settings", systemImage: "arrow.counterclockwise")
                            Spacer()
                        }
                    }
                } footer: {
                    Text("This will reset all reading settings to their default values. Your library will not be affected.")
                }
            }
            .navigationTitle("Settings")
            .alert("Reset Settings", isPresented: $showingResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    readingSettings.resetToDefaults()
                }
            } message: {
                Text("Are you sure you want to reset all settings to their default values?")
            }
        }
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }
}

// MARK: - Font Settings View

struct FontSettingsView: View {
    @EnvironmentObject var readingSettings: ReadingSettings
    
    var body: some View {
        List {
            Section {
                ForEach(ReadingFont.allCases, id: \.self) { font in
                    Button {
                        readingSettings.readingFont = font
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(font.rawValue)
                                    .font(font.font(size: 17))
                                    .foregroundStyle(.primary)
                                Text("The quick brown fox jumps over the lazy dog")
                                    .font(font.font(size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                            if readingSettings.readingFont == font {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            } header: {
                Text("Font Family")
            } footer: {
                Text("Choose a font that's comfortable for extended reading sessions.")
            }
            
            Section("Size") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Font Size")
                        Spacer()
                        Text("\(Int(readingSettings.fontSize)) pt")
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Image(systemName: "textformat.size.smaller")
                            .foregroundStyle(.secondary)
                        Slider(value: $readingSettings.fontSize, in: 12...32, step: 1)
                        Image(systemName: "textformat.size.larger")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            
            Section("Preview") {
                Text("This is a preview of your selected font settings. Adjust the size and family until it feels comfortable to read.")
                    .font(readingSettings.currentFont())
                    .padding(.vertical, 8)
            }
        }
        .navigationTitle("Font")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Layout Settings View

struct LayoutSettingsView: View {
    @EnvironmentObject var readingSettings: ReadingSettings
    
    var body: some View {
        List {
            Section("Line Spacing") {
                ForEach(LineSpacing.allCases, id: \.self) { spacing in
                    Button {
                        readingSettings.lineSpacing = spacing
                    } label: {
                        HStack {
                            Text(spacing.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if readingSettings.lineSpacing == spacing {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section("Text Alignment") {
                ForEach(TextAlignment.allCases, id: \.self) { alignment in
                    Button {
                        readingSettings.textAlignment = alignment
                    } label: {
                        HStack {
                            Image(systemName: alignmentIcon(for: alignment))
                            Text(alignment.rawValue)
                                .foregroundStyle(.primary)
                            Spacer()
                            if readingSettings.textAlignment == alignment {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                    }
                }
            }
            
            Section("Margins") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Margin Size")
                        Spacer()
                        Text("\(Int(readingSettings.marginSize)) pt")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $readingSettings.marginSize, in: 8...48, step: 4)
                }
                .padding(.vertical, 4)
            }
            
            Section("Paragraph Spacing") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Spacing")
                        Spacer()
                        Text("\(Int(readingSettings.paragraphSpacing)) pt")
                            .foregroundStyle(.secondary)
                    }
                    
                    Slider(value: $readingSettings.paragraphSpacing, in: 0...32, step: 4)
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Layout")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func alignmentIcon(for alignment: TextAlignment) -> String {
        switch alignment {
        case .left: return "text.alignleft"
        case .center: return "text.aligncenter"
        case .justified: return "text.justify"
        }
    }
}

// MARK: - Page Theme Settings View

struct PageThemeSettingsView: View {
    @EnvironmentObject var readingSettings: ReadingSettings
    
    var body: some View {
        List {
            Section {
                ForEach(PageTheme.allCases, id: \.self) { theme in
                    Button {
                        readingSettings.pageTheme = theme
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(theme.backgroundColor)
                                    .frame(width: 60, height: 80)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                
                                VStack(spacing: 4) {
                                    ForEach(0..<4, id: \.self) { _ in
                                        RoundedRectangle(cornerRadius: 1)
                                            .fill(theme.textColor)
                                            .frame(width: 40, height: 4)
                                    }
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(theme.rawValue)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text(themeDescription(for: theme))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            
                            Spacer()
                            
                            if readingSettings.pageTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                                    .fontWeight(.semibold)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            } header: {
                Text("Page Theme")
            } footer: {
                Text("Choose a background that reduces eye strain for your reading environment.")
            }
            
            Section("Brightness") {
                Toggle("Auto Brightness", isOn: $readingSettings.autoBrightness)
                
                if !readingSettings.autoBrightness {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Screen Brightness")
                            Spacer()
                            Text("\(Int(readingSettings.brightness * 100))%")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "sun.min")
                                .foregroundStyle(.secondary)
                            Slider(value: $readingSettings.brightness, in: 0.1...1.0)
                                .onChange(of: readingSettings.brightness) { _, newValue in
                                    UIScreen.main.brightness = newValue
                                }
                            Image(systemName: "sun.max")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("Page Theme")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    private func themeDescription(for theme: PageTheme) -> String {
        switch theme {
        case .light: return "Bright white background for well-lit environments"
        case .sepia: return "Warm, paper-like tones reduce eye strain"
        case .dark: return "Dark gray for comfortable reading at night"
        case .black: return "Pure black for OLED screens and low light"
        }
    }
}

// MARK: - Theme Picker View

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    
    var body: some View {
        List {
            Section {
                ForEach(AppTheme.allCases, id: \.self) { theme in
                    Button {
                        withAnimation {
                            themeManager.currentTheme = theme
                        }
                    } label: {
                        HStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: theme.gradientColors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 36, height: 36)
                            }
                            
                            Text(theme.rawValue)
                                .foregroundStyle(.primary)
                            
                            Spacer()
                            
                            if themeManager.currentTheme == theme {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(theme.color)
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                }
            } footer: {
                Text("The accent color is used throughout the app for buttons, highlights, and UI elements.")
            }
        }
        .navigationTitle("Accent Color")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    SettingsView()
        .environmentObject(ReadingSettings.shared)
}
