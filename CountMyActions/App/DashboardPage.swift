import SwiftUI

struct DashboardPage: View {
    var body: some View {
        
        NavigationView {
            TabView {
                ZStack {
                    VStack {
                        
                        ZStack {
                            Image("background_black")
                                .resizable()
                                .scaledToFill()
                                .frame(height: 430)
                                .clipShape(RoundedRectangle(cornerRadius: 400)) // Adjust cornerRadius as needed
                                .opacity(1)
                                .edgesIgnoringSafeArea(.all)

                            
                            VStack(alignment: .leading) {
                                VStack(alignment: .leading) {
                                    Text("Welcome User!")
                                        .font(.largeTitle)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.white)
                                    
                                    Text("Courses Completed: ")
                                        .font(.title)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color.white)
                                    
                                    Text("0")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.yellow)
                                    
                                    Text("Total letters: ")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.white)
                                    
                                    Text("0")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.yellow)
                                    
                                    Text("Total Words")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.white)
                                    
                                    Text("0")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color.yellow)
                                }
                            }
                            .padding(.bottom, 100.0)
                                                    
                        }
                        Spacer()
                        LazyVGrid(columns: Array(repeating: GridItem(), count: 2), spacing: 10) {
                                                    ForEach(0..<4) { index in
                                                        CardView(index: index)
                                                    }
                        }
                                                
                        Spacer()
                        
                    }
                }
                .navigationBarBackButtonHidden(true)
                .background(Color("LightBackground").edgesIgnoringSafeArea(.all))

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
