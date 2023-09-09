import SwiftUI

struct PhrasesPage: View {
    let phrases = [
        ("Yes", "checkmark.seal"),
        ("No", "xmark.seal"),
        ("I Love You", "heart.fill"),
        ("Bathroom", "toilet.fill"),
        ("Bored", "bed.double.fill"),
        ("Please", "hand.raised")
    ]

    var body: some View {
        NavigationView {
            VStack {
                Text("Phrases")
                    .font(.largeTitle)
                    .padding()
                
                List {
                    ForEach(phrases, id: \.0) { phrase, iconName in
                        PhraseRow(phrase: phrase, iconName: iconName)
                    }
                }
                .listStyle(PlainListStyle())
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct PhraseRow: View {
    let phrase: String
    let iconName: String
    
    var body: some View {
        HStack {
            Image(systemName: iconName)
                .foregroundColor(.blue)
                .font(.title)
            Text(phrase)
                .frame(maxWidth: .infinity, alignment: .center) 
        }
        .padding(.vertical, 8)
    }
}


struct PhrasesPage_Previews: PreviewProvider {
    static var previews: some View {
        PhrasesPage()
    }
}

