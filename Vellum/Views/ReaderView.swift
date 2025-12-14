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
        GeometryReader { geometry in
            ZStack {
                // Background
                readingSettings.pageTheme.backgroundColor
                    .ignoresSafeArea()
                
                // Content
                if renderer.isLoading {
                    ProgressView("Loading...")
                        .foregroundStyle(readingSettings.pageTheme.textColor)
                } else if let error = renderer.error {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.orange)
                        Text(error)
                            .foregroundStyle(readingSettings.pageTheme.textColor)
                    }
                } else {
                    documentContent(geometry: geometry)
                }
                
                // Controls overlay
                if showingControls {
                    controlsOverlay
                }
                
                // Tap zones for page turning
                if readingSettings.tapToTurn && !readingSettings.scrollMode {
                    tapZones(geometry: geometry)
                }
            }
        }
        .statusBarHidden(!showingControls)
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
        }
        .sheet(isPresented: $showingBookmarks) {
            BookmarksSheet(document: document, renderer: renderer)
        }
        .gesture(
            TapGesture()
                .onEnded { _ in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showingControls.toggle()
                    }
                }
        )
    }
    
    // MARK: - Document Content
    
    @ViewBuilder
    private func documentContent(geometry: GeometryProxy) -> some View {
        let fileType = document.fileType?.lowercased() ?? "pdf"
        
        switch fileType {
        case "pdf":
            PDFReaderContent(renderer: renderer, settings: readingSettings)
        case "txt", "rtf":
            TextReaderContent(renderer: renderer, settings: readingSettings)
        default:
            Text("Unsupported format")
                .foregroundStyle(readingSettings.pageTheme.textColor)
        }
    }
    
    // MARK: - Controls Overlay
    
    private var controlsOverlay: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
                
                Spacer()
                
                Text(document.title ?? "Document")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button {
                        showingBookmarks = true
                    } label: {
                        Image(systemName: "bookmark")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "textformat.size")
                            .font(.body.weight(.medium))
                            .foregroundStyle(.primary)
                            .padding(10)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding()
            .background(
                LinearGradient(
                    colors: [readingSettings.pageTheme.backgroundColor, readingSettings.pageTheme.backgroundColor.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            
            Spacer()
            
            // Bottom bar
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
    
    // MARK: - Tap Zones
    
    private func tapZones(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left tap zone - previous page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.3)
                .onTapGesture {
                    withAnimation {
                        renderer.previousPage()
                    }
                }
            
            // Center tap zone - toggle controls
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.4)
            
            // Right tap zone - next page
            Color.clear
                .contentShape(Rectangle())
                .frame(width: geometry.size.width * 0.3)
                .onTapGesture {
                    withAnimation {
                        renderer.nextPage()
                    }
                }
        }
    }
}

// MARK: - PDF Reader Content

struct PDFReaderContent: View {
    @ObservedObject var renderer: DocumentRenderer
    let settings: ReadingSettings
    
    var body: some View {
        if let pdfDocument = renderer.getPDFDocument() {
            PDFKitView(document: pdfDocument, currentPage: $renderer.currentPage)
                .ignoresSafeArea()
        }
    }
}

struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument
    @Binding var currentPage: Int
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .horizontal
        pdfView.usePageViewController(true)
        pdfView.backgroundColor = .clear
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged),
            name: .PDFViewPageChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateUIView(_ pdfView: PDFView, context: Context) {
        if let page = document.page(at: currentPage),
           pdfView.currentPage != page {
            pdfView.go(to: page)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject {
        var parent: PDFKitView
        
        init(_ parent: PDFKitView) {
            self.parent = parent
        }
        
        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPage = pdfView.currentPage,
                  let pageIndex = pdfView.document?.index(for: currentPage) else { return }
            
            DispatchQueue.main.async {
                if self.parent.currentPage != pageIndex {
                    self.parent.currentPage = pageIndex
                }
            }
        }
    }
}

// MARK: - Text Reader Content

struct TextReaderContent: View {
    @ObservedObject var renderer: DocumentRenderer
    let settings: ReadingSettings
    
    var body: some View {
        ScrollView {
            if let text = renderer.getTextContent() {
                Text(text)
                    .font(settings.currentFont())
                    .foregroundStyle(settings.pageTheme.textColor)
                    .lineSpacing(settings.fontSize * (settings.lineSpacing.multiplier - 1))
                    .multilineTextAlignment(settings.textAlignment.swiftUIAlignment)
                    .padding(.horizontal, settings.marginSize)
                    .padding(.vertical, 40)
            }
        }
        .background(settings.pageTheme.backgroundColor)
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
