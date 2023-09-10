/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's overlay view.
*/

import SwiftUI
import ConfettiSwiftUI

struct OverlayView: View {

    let count: Float
    let flip: () -> Void
    let max = 50
    @State private var hasFinished: Bool = false
    var theString = "A"
    @State private var isZStackVisible: Bool = true
    @State private var counter: Int = 0

    func incrementPhrasesValue() {
        let currentPhrasesValue = UserDefaults.standard.integer(forKey: "Phrases")

        let incrementedValue = currentPhrasesValue + 1
        UserDefaults.standard.set(incrementedValue, forKey: "Phrases")
    }
    
    func incrementLetterValue() {
        let currentPhrasesValue = UserDefaults.standard.integer(forKey: "Phrases")

        let incrementedValue = currentPhrasesValue + 1
        UserDefaults.standard.set(incrementedValue, forKey: "Letters")
    }

    var body: some View {
        VStack {
            if isZStackVisible && !hasFinished {
                HStack {
                    Spacer()
                    HStack(spacing: 40) {
                        ZStack {
                            Circle()
                                .stroke(
                                    Color.green.opacity(0.5),
                                    lineWidth: 30
                                )
                            Circle()
                                .trim(from: 0, to: CGFloat(count) / CGFloat(max))
                                .stroke(
                                    Color.green,
                                    style: StrokeStyle(
                                        lineWidth: 30,
                                        lineCap: .round
                                    )
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut, value: CGFloat(count) / CGFloat(max))
                        }
                        .padding(/*@START_MENU_TOKEN@*/.all/*@END_MENU_TOKEN@*/)
                        .frame(width: 150, height: 150)
                        VStack(alignment: .leading) {
                            Text("Current:")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color.black)
                            Text(theString)
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(Color.black)
                        }
                        
                    }
                    Spacer()
                }
                .bubbleBackground()
            }
            Spacer()

            HStack {
                Button {
                    flip()
                } label: {
                    Label("Flip", systemImage: "arrow.triangle.2.circlepath.camera.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 30)) // Adjust the size as needed
                        .frame(width: 60, height: 60)
                        .labelStyle(.iconOnly)
                        .bubbleBackground()

                }

                Spacer()
                
                Button {
                    isZStackVisible.toggle()  // <-- 3. Toggle the state on button click
                } label: {
                    Label("Eye", systemImage: "eye.fill")
                        .foregroundColor(.black)
                        .font(.system(size: 30)) // Adjust the size as needed
                        .frame(width: 60, height: 60)
                        .labelStyle(.iconOnly)
                        .bubbleBackground()
                }
            }
        }
        .onChange(of: count) { newValue in
            if newValue >= Float(max) {
                // Your logic here
                //print("Count has reached or exceeded the max!")
                if hasFinished == false {
                    counter += 1
                    hasFinished = true
                    if theString.count == 1 {
                        incrementLetterValue()
                    } else {
                        incrementPhrasesValue()
                    }
                    
                }
            }
        }
        .padding()
        .confettiCannon(counter: $counter)
    }
}


extension View {
    func bubbleBackground() -> some View {
        self.padding()
            .background {
                RoundedRectangle(cornerRadius: 16)
                    .foregroundColor(.white)
            }
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(count: 3.0) { }
            .background(Color.red.opacity(0.4))

    }
}
