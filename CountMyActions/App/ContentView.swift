import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationView {
            VStack {
                Spacer()
                
                Image("hearthand")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                Spacer()
                
                VStack {
                    Text("Hands-On")
                        .font(.system(size: 55))
                        .fontWeight(.bold)
                    
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
            .background(Color.blue)
            .edgesIgnoringSafeArea(.all)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

