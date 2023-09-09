import SwiftUI

struct HomePage1: View {
    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Text("Free learning with")
                    Text("Hands-On")
                        .foregroundColor(.blue)
                    Text("Experience")
                }

                Image("hand")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                
                NavigationLink(destination: HomePage2()) {
                    Circle()
                        .frame(width: 60, height: 60)
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
        .navigationBarBackButtonHidden(true)
    }
}



struct HomePage1_Previews: PreviewProvider {
    static var previews: some View {
        HomePage1()
    }
}

