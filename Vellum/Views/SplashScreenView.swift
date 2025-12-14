import SwiftUI

struct SplashScreenView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: ThemeManager.shared.gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.white)
                }
                .scaleEffect(scale)
                
                // App Name
                VStack(spacing: 4) {
                    Text("Vellum")
                        .font(.system(size: 36, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    
                    Text("Your Personal Library")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.8))
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                scale = 1.0
            }
            
            withAnimation(.easeIn(duration: 0.4).delay(0.2)) {
                opacity = 1.0
            }
        }
    }
}

#Preview {
    SplashScreenView()
}
