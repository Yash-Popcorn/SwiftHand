import SwiftUI

struct HomePage1: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color("LightBlue").edgesIgnoringSafeArea(.all)
                
                GeometryReader { geometry in
                    VStack {
                        Text("Free learning with Hands-On experience")
                            .font(.system(size: min(geometry.size.width * 0.1, 50)))
                            .fontWeight(.bold)
                            .foregroundColor(Color.white)
                            .padding(.bottom, 10)
                        
                        Image("handwhite")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geometry.size.width * 1, height: geometry.size.height * 0.63)
                        GotItButtonView()
                    }
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

