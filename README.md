# Vellum

A minimalistic and elegant iOS book reader app designed for a classy reading experience.

## Features

### Library Management
- **Import Documents**: Import PDFs, EPUBs, TXT, and RTF files from your iPhone
- **Smart Organization**: Automatically extracts metadata (title, author, cover) from PDFs
- **Collections**: Create custom collections to organize your reading
- **Favorites**: Mark your favorite books for quick access
- **Search & Sort**: Find books quickly with search and multiple sort options

### Reading Experience
- **PDF Reader**: Native PDF rendering with smooth page navigation
- **Text Reader**: Support for plain text and RTF documents
- **Progress Tracking**: Automatic reading progress saved per document
- **Bookmarks**: Add bookmarks to save your place

### Customization Options
- **Fonts**: Choose from 8 beautiful reading fonts including Georgia, Palatino, Baskerville, and more
- **Font Size**: Adjustable from 12pt to 32pt
- **Page Themes**: 4 themes - Light, Sepia, Dark, and Black (OLED)
- **Line Spacing**: Tight, Normal, Relaxed, or Loose
- **Text Alignment**: Left, Justified, or Center
- **Margins**: Customizable margin sizes
- **Brightness**: Manual or auto brightness control

### App Themes
- Sepia (default)
- Midnight
- Ocean
- Forest
- Lavender

### Additional Features
- **Keep Screen Awake**: Prevent screen dimming while reading
- **Tap to Turn Pages**: Tap left/right edges to navigate
- **Progress Bar**: Visual reading progress indicator
- **Page Numbers**: Show current page and total pages
- **Continue Reading**: Quick access to recently read books
- **Reading Stats**: Track your library and reading progress

## Requirements

- iOS 17.0+
- iPhone or iPad

## Architecture

The app follows a clean architecture pattern inspired by Vibic:

```
Vellum/
├── VellumApp.swift          # App entry point
├── ContentView.swift        # Main tab view
├── Core/
│   ├── ThemeManager.swift       # App accent color themes
│   ├── ReadingSettings.swift    # Reading customization settings
│   ├── CoreDataManager.swift    # Data persistence
│   ├── LibraryController.swift  # Library management
│   └── DocumentRenderer.swift   # Document rendering
├── Models/
│   └── VellumModel.xcdatamodeld # Core Data model
├── Views/
│   ├── LibraryView.swift        # Main library grid/list
│   ├── ReaderView.swift         # Document reader
│   ├── SettingsView.swift       # App settings
│   ├── CollectionsView.swift    # Collections management
│   ├── CurrentlyReadingView.swift # Reading tab
│   └── SplashScreenView.swift   # Launch screen
└── Assets.xcassets/
```

## Supported File Types

- **PDF** (.pdf) - Full support with cover extraction
- **EPUB** (.epub) - Basic support
- **Plain Text** (.txt) - Full support
- **Rich Text** (.rtf) - Full support

## Building

1. Open `Vellum.xcodeproj` in Xcode 15+
2. Select your development team in Signing & Capabilities
3. Build and run on your device or simulator

## App Store Preparation

The app is built with App Store submission in mind:
- Proper Info.plist configuration
- Document type declarations for file handling
- App category set to Books
- Support for all iPhone and iPad orientations
- Privacy-respecting (no network requests, all data stored locally)

## License

MIT License
