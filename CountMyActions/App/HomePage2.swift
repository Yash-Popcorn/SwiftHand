import SwiftUI

struct HomePage2: View {
    var body: some View {
        NavigationView {
            VStack {
                Text("Save Data")
                
                Image("save")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 200, height: 200)
                
                Spacer()
                
                NavigationLink(destination: DashboardPage()) {
                    Circle()
                        .frame(width: 60, height: 60)
                        .foregroundColor(.red)
                        .overlay(
                            Image(systemName: "arrow.right")
                                .foregroundColor(.white)
                        )
                        .shadow(radius: 4)
                        .padding(.top, 20)
                }
                
                Spacer()
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


struct HomePage2_Previews: PreviewProvider {
    static var previews: some View {
        HomePage2()
    }
}

