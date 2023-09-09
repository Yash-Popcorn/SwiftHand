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
                    .frame(width: 200,
                        height: 200)
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

