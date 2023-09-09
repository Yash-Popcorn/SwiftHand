import SwiftUI

struct HomePage1: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color("LightBackground").edgesIgnoringSafeArea(.all)
                
                VStack {
                    HStack {
                        Text("Free learning with") +
                        Text(" Hands-On").foregroundColor(.blue) +
                        Text(" Experience")
                    }
                    .padding(/*@START_MENU_TOKEN@*/.all, 20.0/*@END_MENU_TOKEN@*/)
                    .font(.largeTitle)
                    .fontWeight(.semibold)
                    
                    Image("hand")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 600, height: 500)
                    
                    NavigationLink(destination: HomePage2()) {
                        Circle()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.red)
                            .overlay(
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                            )
                            .shadow(radius: 4)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}



struct HomePage1_Previews: PreviewProvider {
    static var previews: some View {
        HomePage1()
    }
}

