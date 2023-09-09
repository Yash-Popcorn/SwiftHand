import SwiftUI
struct ContentView: View {
    var desc = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
    var body: some View {
        NavigationView {
            ZStack {
                // This Color view will fill the entire screen
                Color("LightBackground").edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()

                    Image("hearthand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                    Spacer()

                    VStack(alignment: .leading) {
                        Text("Hands-On")
                            .font(.system(size: 55))
                            .fontWeight(.bold)
                        Text(desc)
                            .font(.body)
                            .fontWeight(.semibold)
                    }
                    Spacer()

                    NavigationLink(destination: HomePage1()) {
                        Text("Get Started")
                            .frame(width: 200, height: 50)
                            .background(Color.red)
                            .foregroundColor(.white)
                            .font(.headline)
                            .cornerRadius(10)
                    }
                    .padding(.bottom, 20)
                }
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

