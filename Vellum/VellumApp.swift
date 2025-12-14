import SwiftUI

@main
struct VellumApp: App {
    let coreDataManager = CoreDataManager.shared
    @StateObject private var libraryController = LibraryController.shared
    @StateObject private var readingSettings = ReadingSettings.shared
    @ObservedObject private var themeManager = ThemeManager.shared
    @State private var showSplash = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environment(\.managedObjectContext, coreDataManager.viewContext)
                    .environmentObject(libraryController)
                    .environmentObject(readingSettings)
                    .tint(themeManager.accentColor)
                
                if showSplash {
                    SplashScreenView()
                        .transition(.opacity.animation(.easeOut(duration: 0.5)))
                        .zIndex(1)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.25) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showSplash = false
                    }
                }
            }
        }
    }
}
