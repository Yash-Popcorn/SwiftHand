import SwiftUI

struct DashboardPage: View {
    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1).edgesIgnoringSafeArea(.all)
                VStack {
                    BigStatCard()
                    Divider()
                    Text("Dashboard")
                        .font(.system(size: 40))
                        .fontWeight(.bold)
                        .foregroundColor(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1))
                        .padding(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    ScrollView(showsIndicators: false) {
                        VStack {
                            ChildCard(title: "Letters",
                                      image: "ABC",
                                      desc: "Learn the ASL alphabets")
                            ChildCard(title: "Phrases", image: "Phrases", desc: "Learn unique gestures")
                            ChildCard(title: "Game", image: "Joystick", desc: "Practice by learning a few phrases")
                        }
                    }

                    Spacer()
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}


struct BigStatCard: View {
    
    @State private var lettersValue: Int = 0
    @State private var phrasesValue: Int = 0

    func fetchValuesFromUserDefaults() {
        lettersValue = UserDefaults.standard.integer(forKey: "Letters")
        phrasesValue = UserDefaults.standard.integer(forKey: "Phrases")
    }
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.sRGB, red: 255/255, green: 202/255, blue: 67/255, opacity: 1))
                .frame(width: 390, height: 230)
            
            Image("Stripes")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 150, height: 110)
                .mask(
                    RoundedRectangle(cornerRadius: 16)
                )
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.sRGB, red: 0.2, green: 0.2, blue: 0.2, opacity: 1))
                            .frame(width: 160, height: 55)
                        Text("Practiced")
                            .fontWeight(.bold)
                            .foregroundColor(Color.yellow)
                            .font(.system(size: 20))

                    }
                    Text("\(lettersValue) letters")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.black)
                    Text("\(phrasesValue) phrases")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color.black)
                }
                Image("Trophy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .padding(0.0)
                    .frame(width: 160, height: 150)
            }
            .padding(.all)
            
        }
        .onAppear(perform: fetchValuesFromUserDefaults)
    }
}


struct ChildCard: View {
    var title = ""
    var image = ""
    var desc = ""
    var body: some View {
        NavigationLink(destination: Group {
            if title == "Phrases" {
                ListView(isAlphabetic: false)
            } else if title == "Game" {
                CameraWithPosesAndOverlaysView()
            } else {
                ListView(isAlphabetic: true)
            }
        }) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1))
                    .frame(width: 380, height: 190)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color(.sRGB, red: 0.85, green: 0.85, blue: 0.85, opacity: 1), lineWidth: 3)
                    )
                HStack {
                    Image(image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .padding(0.0)
                        .frame(width: 150, height: 140)
                    VStack(alignment: .leading) {
                        Text(title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.sRGB, red: 0.25, green: 0.25, blue: 0.25, opacity: 1))
                        Text(desc)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(Color(.sRGB, red: 0.25, green: 0.25, blue: 0.25, opacity: 1))
                            .multilineTextAlignment(.leading)
                    }
                }
            }
        }
    }
}


struct DashboardPage_Previews: PreviewProvider {
    static var previews: some View {
        DashboardPage()
    }
}

