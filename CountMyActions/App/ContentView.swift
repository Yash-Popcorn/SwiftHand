import SwiftUI
struct ContentView: View {
    var desc = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
    var body: some View {
        NavigationView {
            ZStack {
                Color("LightBlue").edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()
                    Text("Hands-On")
                        .font(.system(size: 60))
                        .fontWeight(.bold)
                        .foregroundColor(Color.white)

                        
                    Image("hearthand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 300, height: 400)
                    Spacer()
                    StartButtonView()
                    Spacer()
                }
            }
        }
    }
}

struct StartButtonView: View {
    var body: some View {
        NavigationLink(destination: HomePage1()) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.sRGB, red: 0.85, green: 0.85, blue: 0.85, opacity: 1))  // Darker gray
                    .frame(width: 280, height: 70)  // Increase width and height
                    .offset(y: 7)  // Adjust y-offset

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(  // Add an overlay to the RoundedRectangle
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.sRGB, red: 0.85, green: 0.85, blue: 0.85, opacity: 1), lineWidth: 2.5)  // Adjust lineWidth
                    )
                    .frame(width: 280, height: 70)  // Increase width and height

                Text("Start Now")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.sRGB, red: 0.25, green: 0.25, blue: 0.25, opacity: 1))
            }
        }
    }
}

struct GotItButtonView: View {
    var body: some View {
        NavigationLink(destination: DashboardPage()) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.sRGB, red: 0.85, green: 0.85, blue: 0.85, opacity: 1))  // Darker gray
                    .frame(width: 280, height: 70)  // Increase width and height
                    .offset(y: 7)  // Adjust y-offset

                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white)
                    .overlay(  // Add an overlay to the RoundedRectangle
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.sRGB, red: 0.85, green: 0.85, blue: 0.85, opacity: 1), lineWidth: 2.5)  // Adjust lineWidth
                    )
                    .frame(width: 280, height: 70)  // Increase width and height

                Text("Got It")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(.sRGB, red: 0.25, green: 0.25, blue: 0.25, opacity: 1))
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

