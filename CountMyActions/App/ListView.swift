import SwiftUI

struct ListView: View {
    var phrases: [String] = ["Yes", "No", "I Love You", "Bathroom", "Bored", "Please"]
    let alphabets: [String] = ["A", "B", "C", "D", "E", "F", "G", "H", "I", "J", "K", "L", "M", "N", "O", "P", "R", "S", "T", "U", "W"]
    var isAlphabetic = false

    
    var body: some View {
        NavigationView {
            ZStack {
                Color(.sRGB, red: 1, green: 1, blue: 1, opacity: 1).edgesIgnoringSafeArea(.all)
                ScrollView {
                    VStack(spacing: 15) {
                        if isAlphabetic {
                            ForEach(alphabets, id: \.self) { alphabet in
                                SmallCard(title: alphabet)
                            }
                        } else {
                            ForEach(phrases, id: \.self) { alphabet in
                                SmallCard(title: alphabet)
                            }
                        }
                    }
                }
            }
        }
    }
}

struct SmallCard: View {
    var title = ""
    var body: some View {
        NavigationLink(destination: CameraWithPosesAndOverlaysView(theString: title)) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1))
                    .frame(width: 390, height: 80)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color(.sRGB, red: 0.9, green: 0.9, blue: 0.9, opacity: 1), lineWidth: 5)
                    )
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 60)
                            .fill(Color(.sRGB, red: 0.95, green: 0.95, blue: 0.95, opacity: 1))
                            .frame(width: 54, height: 54)
                            .overlay(
                                RoundedRectangle(cornerRadius: 60)
                                    .stroke(Color(.sRGB, red: 0.4, green: 0.9, blue: 0.9, opacity: 1), lineWidth: 4)
                            )
                        Image("hearthand")
                            .resizable()
                            .frame(width: 34, height: 34)
                    }
                    Text(title)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(.sRGB, red: 0.3, green: 0.3, blue: 0.3, opacity: 1))
                }
                .padding(.leading)
            }
        }
    }
}

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        ListView()
    }
}

