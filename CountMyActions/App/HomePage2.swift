import SwiftUI

struct HomePage2: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color("LightBackground").edgesIgnoringSafeArea(.all)
                
                VStack {
                    
                    Text("Save Data")
                        .font(.system(size: 55))
                        .fontWeight(.semibold)
                        .foregroundColor(Color.black)
                    
                    Spacer()
                    Image("save")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 600, height: 350)
                    
                    Spacer()
                    
                    NavigationLink(destination: DashboardPage()) {
                        Circle()
                            .frame(width: 120, height: 120)
                            .foregroundColor(.red)
                            .overlay(
                                Image(systemName: "arrow.right")
                                    .foregroundColor(.white)
                                    .font(.system(size: 40)) // Adjust the size as needed
                                
                            )
                            .shadow(radius: 4)
                    }
                    .padding(.top, 20)
                    
                    Spacer()
                }
            }
        }.navigationBarBackButtonHidden(true)
    }
}


struct HomePage2_Previews: PreviewProvider {
    static var previews: some View {
        HomePage2()
    }
}

