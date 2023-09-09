import SwiftUI

struct LettersPage: View {
    let alphabet = [
        "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
        "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
        "U", "V", "W", "X", "Y", "Z"
    ]

    var body: some View {
        NavigationView {
            VStack {
                Text("Alphabet")
                    .font(.largeTitle)
                    .padding()
                
                List(alphabet, id: \.self) { letter in
                    AlphabetRow(alphabet: letter)
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct AlphabetRow: View {
    let alphabet: String
    
    var body: some View {
        HStack {
            Text(alphabet)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(.vertical, 8)
    }
}

struct LettersPage_Previews: PreviewProvider {
    static var previews: some View {
        LettersPage()
    }
}

