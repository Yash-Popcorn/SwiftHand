import SwiftUI

struct DashboardPage: View {
    var body: some View {
        
        NavigationView {
            TabView {
            ZStack {
                VStack {
                    Image("background")
                        .resizable()
                        .scaledToFill()
                        .edgesIgnoringSafeArea(.all)
                        .opacity(0.5)
                        .frame(height: 250)
                    
                    Spacer()
                }
                
                VStack(alignment: .leading) {
                    VStack(alignment: .leading) {
                        Text("Welcome User!")
                            .font(.title)
                        
                        Text("Courses Completed: ")
                            .font(.headline)
                        
                        Text("0")
                            .font(.title)
                        
                        Text("Total letters: ")
                            .font(.headline)
                        
                        Text("0")
                            .font(.title)
                        
                        Text("Total Words")
                            .font(.headline)
                        
                        Text("0")
                            .font(.title)
                    }
                    .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                    Spacer()
                    
                    // Add 2x2 Card Grid
                    LazyVGrid(columns: Array(repeating: GridItem(), count: 2), spacing: 10) {
                        ForEach(0..<4) { index in
                            CardView(index: index)
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
                .padding()
            }
            .navigationBarBackButtonHidden(true)
        }
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                HStack {
                    
                    Button(action: {
                        // Action for Home button
                    }) {
                        Image(systemName: "house")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Button(action: {
                        // Action for Hand button
                    }) {
                        Image(systemName: "hand.raised")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                    Button(action: {
                        // Action for Checkmark button
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title)
                            .foregroundColor(.blue)
                    }
                    .padding()
                    
                }
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
