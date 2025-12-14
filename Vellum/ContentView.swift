import SwiftUI

struct ContentView: View {
    @EnvironmentObject var libraryController: LibraryController
    @EnvironmentObject var readingSettings: ReadingSettings
    @State private var selectedTab: Tab = .library
    @State private var showingSettings = false
    
    enum Tab {
        case library
        case collections
        case reading
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TabView(selection: $selectedTab) {
                LibraryView()
                    .tabItem {
                        Label("Library", systemImage: "books.vertical")
                    }
                    .tag(Tab.library)
                
                CollectionsView()
                    .tabItem {
                        Label("Collections", systemImage: "folder")
                    }
                    .tag(Tab.collections)
                
                CurrentlyReadingView()
                    .tabItem {
                        Label("Reading", systemImage: "book")
                    }
                    .tag(Tab.reading)
            }
            
            // Floating Settings Button
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.accentColor)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
            }
            .padding(.top, 4)
            .padding(.leading, 16)
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .onOpenURL { url in
            libraryController.importDocument(from: url)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext, CoreDataManager.shared.viewContext)
        .environmentObject(LibraryController.shared)
        .environmentObject(ReadingSettings.shared)
}
