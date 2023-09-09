import SwiftUI
struct ContentView: View {
    var desc = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt"
    var body: some View {
        NavigationView {
            ZStack {
                Color("LightBackground").edgesIgnoringSafeArea(.all)

                VStack {
                    Spacer()

                    Image("hearthand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 200, height: 200)
                    Spacer()

                    VStack(spacing: 25) {
                        VStack(alignment: .leading) {
                            Text("Hands-On")
                                .font(.system(size: 55))
                                .fontWeight(.bold)
                            Text(desc)
                                .font(.body)
                                .fontWeight(.semibold)
                        }
                        VStack(alignment: .center, spacing: -10) {
                            NavigationLink(destination: HomePage1()) {
                                Text("Get Started")
                                    .frame(width: 200, height: 50)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .cornerRadius(10)
                            }
                            .padding(.bottom, 20)
                            
                            Text("Saves in icloud")
                                .fontWeight(.semibold)
                                .foregroundColor(Color.blue)

                        }                    }
                    .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                    Spacer()
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

