import SwiftUI
import PDFKit

struct ReaderView: View {
    let document: Document
    
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var readingSettings: ReadingSettings
    @StateObject private var renderer = DocumentRenderer()
    
    @State private var showingControls = true
    @State private var showingSettings = false
    @State private var showingTableOfContents = false
    @State private var showingBookmarks = false
    @State private var brightness: Double = UIScreen.main.brightness
    
    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                ZStack {
                    // Background
                    readingSettings.pageTheme.backgroundColor
                        .ignoresSafeArea()
                    
                    // Content
                    if renderer.isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading document...")
                                .foregroundStyle(readingSettings.pageTheme.textColor)
                        }
                    } else if renderer.isPaginating && renderer.pages.isEmpty {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Preparing pages...")
                                .foregroundStyle(readingSettings.pageTheme.textColor)
                        }
                    } else if let error = renderer.error {
                        VStack(spacing: 16) {
                            Image(systemName: "exclamationmark.triangle")
                                .font(.largeTitle)
                                .foregroundStyle(.orange)
                            Text(error)
                                .foregroundStyle(readingSettings.pageTheme.textColor)
                                .multilineTextAlignment(.center)
                                .padding()
                        }
                    } else {
                        documentContent(geometry: geometry)
                            .contentShape(Rectangle())
                            .gesture(
                                DragGesture(minimumDistance: 50)
                                    .onEnded { value in
                                        if value.translation.width < -50 {
                                            withAnimation { renderer.nextPage() }
                                        } else if value.translation.width > 50 {
                                            withAnimation { renderer.previousPage() }
                                        }
                                    }
                            )
                            .onTapGesture { location in
                                handleTap(at: location, screenWidth: geometry.size.width)
                            }
                    }
                    
                    // Bottom controls (progress, slider)
                    if showingControls {
                        VStack {
                            Spacer()
                            bottomControlBar
                        }
                    }
                }
            }
            .navigationTitle(document.title ?? "Document")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(showingControls ? .visible : .hidden, for: .navigationBar)
            .toolbar(showingControls ? .visible : .hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        if renderer.isEPUB && !renderer.chapters.isEmpty {
                            Button(action: { showingTableOfContents = true }) {
                                Image(systemName: "list.bullet")
                            }
                        }
                        Button(action: { showingBookmarks = true }) {
                            Image(systemName: "bookmark")
                        }
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "textformat.size")
                        }
                    }
                }
            }
        }
        .onAppear {
            renderer.load(document: document)
            if readingSettings.keepScreenAwake {
                UIApplication.shared.isIdleTimerDisabled = true
            }
            if !readingSettings.autoBrightness {
                UIScreen.main.brightness = readingSettings.brightness
            }
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
            UIScreen.main.brightness = brightness
        }
        .sheet(isPresented: $showingSettings) {
            ReaderSettingsSheet()
                .environmentObject(readingSettings)
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(document: document, renderer: renderer)
        }
        .sheet(isPresented: $showingTableOfContents) {
            EPUBTableOfContentsSheet(renderer: renderer)
        }
    }
    
    private func handleTap(at location: CGPoint, screenWidth: CGFloat) {
        if readingSettings.tapToTurn {
            if location.x < screenWidth * 0.3 {
                withAnimation { renderer.previousPage() }
            } else if location.x > screenWidth * 0.7 {
                withAnimation { renderer.nextPage() }
            } else {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingControls.toggle()
                }
            }
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                showingControls.toggle()
            }
        }
    }
    
    // MARK: - Document Content
    
    @ViewBuilder
    private func documentContent(geometry: GeometryProxy) -> some View {
        PaginatedTextContent(
            renderer: renderer,
            settings: readingSettings,
            availableSize: geometry.size
        )
    }
    
    private var bottomControlBar: some View {
        VStack(spacing: 12) {
            // Progress bar
            if readingSettings.showProgressBar {
                ProgressView(value: renderer.progress)
                    .tint(.accentColor)
                    .padding(.horizontal)
            }
            
            // Page info
            if readingSettings.showPageNumbers {
                HStack {
                    Text("Page \(renderer.currentPage + 1) of \(renderer.totalPages)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Text("\(Int(renderer.progress * 100))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }
            
            // Page slider
            if renderer.totalPages > 1 {
                Slider(
                    value: Binding(
                        get: { Double(renderer.currentPage) },
                        set: { renderer.goToPage(Int($0)) }
                    ),
                    in: 0...Double(max(1, renderer.totalPages - 1)),
                    step: 1
                )
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
        .background(
            LinearGradient(
                colors: [readingSettings.pageTheme.backgroundColor.opacity(0), readingSettings.pageTheme.backgroundColor],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
    
}

// MARK: - Paginated Text Content

struct PaginatedTextContent: View {
    @ObservedObject var renderer: DocumentRenderer
    @ObservedObject var settings: ReadingSettings
    let availableSize: CGSize
    
    @State private var lastPaginationSettings: PaginationSettings?
    
    private struct PaginationSettings: Equatable {
        let fontSize: Double
        let fontName: String
        let lineSpacing: String
        let margins: Double
        let width: CGFloat
        let height: CGFloat
    }
    
    var body: some View {
        VStack {
            if renderer.pages.isEmpty {
                Text("Loading...")
                    .foregroundStyle(settings.pageTheme.textColor)
            } else {
                Text(renderer.getCurrentPageText())
                    .font(settings.currentFont())
                    .foregroundStyle(settings.pageTheme.textColor)
                    .lineSpacing(settings.fontSize * (settings.lineSpacing.multiplier - 1))
                    .multilineTextAlignment(settings.textAlignment.swiftUIAlignment)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .padding(.horizontal, settings.marginSize)
                    .padding(.vertical, 40)
            }
        }
        .background(settings.pageTheme.backgroundColor)
        .onAppear {
            paginateIfNeeded()
        }
        .onChange(of: settings.fontSize) { _, _ in paginateIfNeeded() }
        .onChange(of: settings.readingFont) { _, _ in paginateIfNeeded() }
        .onChange(of: settings.lineSpacing) { _, _ in paginateIfNeeded() }
        .onChange(of: settings.marginSize) { _, _ in paginateIfNeeded() }
        .onChange(of: availableSize) { _, _ in paginateIfNeeded() }
    }
    
    private func paginateIfNeeded() {
        let currentSettings = PaginationSettings(
            fontSize: settings.fontSize,
            fontName: settings.readingFont.rawValue,
            lineSpacing: settings.lineSpacing.rawValue,
            margins: settings.marginSize,
            width: availableSize.width,
            height: availableSize.height
        )
        
        guard currentSettings != lastPaginationSettings else { return }
        lastPaginationSettings = currentSettings
        
        let uiFont = createUIFont()
        let lineSpacingValue = settings.fontSize * (settings.lineSpacing.multiplier - 1)
        
        renderer.paginateText(
            availableSize: availableSize,
            font: uiFont,
            lineSpacing: lineSpacingValue,
            margins: settings.marginSize
        )
    }
    
    private func createUIFont() -> UIFont {
        let size = settings.fontSize
        
        switch settings.readingFont {
        case .system:
            return UIFont.systemFont(ofSize: size)
        case .georgia:
            return UIFont(name: "Georgia", size: size) ?? UIFont.systemFont(ofSize: size)
        case .palatino:
            return UIFont(name: "Palatino", size: size) ?? UIFont.systemFont(ofSize: size)
        case .times:
            return UIFont(name: "Times New Roman", size: size) ?? UIFont.systemFont(ofSize: size)
        case .baskerville:
            return UIFont(name: "Baskerville", size: size) ?? UIFont.systemFont(ofSize: size)
        case .charter:
            return UIFont(name: "Charter", size: size) ?? UIFont.systemFont(ofSize: size)
        case .literata:
            return UIFont(name: "Literata", size: size) ?? UIFont.systemFont(ofSize: size)
        case .openDyslexic:
            return UIFont(name: "OpenDyslexic", size: size) ?? UIFont.systemFont(ofSize: size)
        }
    }
}

// MARK: - Reader Settings Sheet

struct ReaderSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var readingSettings: ReadingSettings
    
    var body: some View {
        NavigationStack {
            List {
                // Font Section
                Section("Font") {
                    Picker("Font Family", selection: $readingSettings.readingFont) {
                        ForEach(ReadingFont.allCases, id: \.self) { font in
                            Text(font.rawValue)
                                .tag(font)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Size")
                            Spacer()
                            Text("\(Int(readingSettings.fontSize))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $readingSettings.fontSize, in: 12...32, step: 1)
                    }
                }
                
                // Layout Section
                Section("Layout") {
                    Picker("Line Spacing", selection: $readingSettings.lineSpacing) {
                        ForEach(LineSpacing.allCases, id: \.self) { spacing in
                            Text(spacing.rawValue).tag(spacing)
                        }
                    }
                    
                    Picker("Text Alignment", selection: $readingSettings.textAlignment) {
                        ForEach(TextAlignment.allCases, id: \.self) { alignment in
                            Text(alignment.rawValue).tag(alignment)
                        }
                    }
                    
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Margins")
                            Spacer()
                            Text("\(Int(readingSettings.marginSize))")
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $readingSettings.marginSize, in: 8...48, step: 4)
                    }
                }
                
                // Theme Section
                Section("Page Theme") {
                    ForEach(PageTheme.allCases, id: \.self) { theme in
                        Button {
                            readingSettings.pageTheme = theme
                        } label: {
                            HStack {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.backgroundColor)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .strokeBorder(Color.secondary.opacity(0.3), lineWidth: 1)
                                    )
                                    .frame(width: 40, height: 30)
                                
                                Text(theme.rawValue)
                                    .foregroundStyle(.primary)
                                
                                Spacer()
                                
                                if readingSettings.pageTheme == theme {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentColor)
                                }
                            }
                        }
                    }
                }
                
                // Reading Experience
                Section("Reading") {
                    Toggle("Keep Screen Awake", isOn: $readingSettings.keepScreenAwake)
                    Toggle("Show Progress Bar", isOn: $readingSettings.showProgressBar)
                    Toggle("Show Page Numbers", isOn: $readingSettings.showPageNumbers)
                    Toggle("Tap to Turn Pages", isOn: $readingSettings.tapToTurn)
                }
            }
            .navigationTitle("Reading Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Bookmarks Sheet

struct BookmarksSheet: View {
    let document: Document
    @ObservedObject var renderer: DocumentRenderer
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        // TODO: Add bookmark functionality
                        dismiss()
                    } label: {
                        Label("Add Bookmark", systemImage: "plus")
                    }
                }
                
                Section("Bookmarks") {
                    if let bookmarks = document.bookmarks as? Set<ReadingBookmark>, !bookmarks.isEmpty {
                        ForEach(Array(bookmarks).sorted { ($0.page) < ($1.page) }, id: \.id) { bookmark in
                            Button {
                                renderer.goToPage(Int(bookmark.page))
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(bookmark.title ?? "Page \(bookmark.page + 1)")
                                            .foregroundStyle(.primary)
                                        if let note = bookmark.note, !note.isEmpty {
                                            Text(note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    Text("Page \(bookmark.page + 1)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } else {
                        Text("No bookmarks yet")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    ReaderView(document: Document())
        .environmentObject(ReadingSettings.shared)
}
