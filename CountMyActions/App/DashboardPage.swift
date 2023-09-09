
import SwiftUI

// 1. Header Component
struct Header: View {
    var body: some View {
        Image("background_black")
            .resizable()
            .scaledToFill()
            .frame(height: 430)
            .clipShape(RoundedRectangle(cornerRadius: 400))
            .opacity(1)
            .edgesIgnoringSafeArea(.all)
    }
}

// 2. StatisticsView Component
struct StatisticsView: View {
    var title: String
    var value: String
    var valueColor: Color
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(title)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(Color.white)
            
            Text(value)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(valueColor)
        }
    }
}

// 3. GridCards Component
struct GridCards: View {
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(), count: 2), spacing: 10) {
            ForEach(0..<4) { index in
                NavigationLink(destination: destinationView(for: index)) {
                    CardView(index: index)
                }
            }
        }
    }
    
    private func destinationView(for index: Int) -> some View {
        switch index {
        case 0:
            return AnyView(LettersPage())
        case 1:
            return AnyView(PhrasesPage())
        case 2:
            return AnyView(DictionaryPage())
        case 3:
            return AnyView(GamesPage())
        default:
            return AnyView(Text(""))
        }
    }
}

// 4. ToolbarButtons Component
struct ToolbarButtons: View {
    var body: some View {
        HStack {
            Button(action: {}) {
                Image(systemName: "house")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding()
            
            Button(action: {}) {
                Image(systemName: "hand.raised")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding()
            
            Button(action: {}) {
                Image(systemName: "checkmark")
                    .font(.title)
                    .foregroundColor(.blue)
            }
            .padding()
        }
    }
}

// Main DashboardPage, now more concise
struct DashboardPage: View {
    var body: some View {
        NavigationView {
            TabView {
                ZStack {
                    VStack {
                        Header()
                        VStack(alignment: .leading) {
                            StatisticsView(title: "Welcome User!", value: "", valueColor: .white)
                            StatisticsView(title: "Courses Completed:", value: "0", valueColor: .yellow)
                            StatisticsView(title: "Total letters:", value: "0", valueColor: .yellow)
                            StatisticsView(title: "Total Words", value: "0", valueColor: .yellow)
                        }
                        .padding(.bottom, 100.0)
                        Spacer()
                        GridCards()
                        Spacer()
                    }
                }
                .navigationBarBackButtonHidden(true)
                .background(Color("LightBackground").edgesIgnoringSafeArea(.all))
            }
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    ToolbarButtons()
                }
            }
        }
    }
}


struct CardView: View {
    var index: Int
    
    var body: some View {
        let cardTitles = ["Letters", "Phrases", "Dictionary", "Games"]
        
        RoundedRectangle(cornerRadius: 10)
            .fill(Color.blue)
            .frame(height: 100)
            .overlay(
                Text(cardTitles[index])
                    .foregroundColor(.white)
                    .font(.headline)
            )
    }
}

struct DashboardPage_Previews: PreviewProvider {
    static var previews: some View {
        DashboardPage()
    }
}
