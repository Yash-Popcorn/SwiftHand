/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's overlay view.
*/

import SwiftUI

struct OverlayView: View {

    let count: Float
    let flip: () -> Void
    let max = 50
    @State private var isZStackVisible: Bool = true  // <-- 1. Add this state variable
    
    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack {
                    if isZStackVisible {  // <-- 2. Bind the visibility to this state
                        ZStack {
                            Circle()
                                .stroke(
                                    Color.pink.opacity(0.5),
                                    lineWidth: 30
                                )
                            Circle()
                                .trim(from: 0, to: CGFloat(count) / CGFloat(max))
                                .stroke(
                                    Color.pink,
                                    style: StrokeStyle(
                                        lineWidth: 30,
                                        lineCap: .round
                                    )
                                )
                                .rotationEffect(.degrees(-90))
                                .animation(.easeOut, value: CGFloat(count) / CGFloat(max))
                        }
                    }
                }
                Spacer()
            }.bubbleBackground()

            Spacer()

            HStack {
                Button {
                    flip()
                } label: {
                    Label("Flip", systemImage: "arrow.triangle.2.circlepath.camera.fill")
                        .foregroundColor(.primary)
                        .labelStyle(.iconOnly)
                        .bubbleBackground()
                }

                Spacer()
                
                Button {
                    isZStackVisible.toggle()  // <-- 3. Toggle the state on button click
                } label: {
                    Label("Eye", systemImage: "eye.fill")
                        .foregroundColor(.primary)
                        .labelStyle(.iconOnly)
                        .bubbleBackground()
                }
            }
        }.padding()
    }
}


extension View {
    func bubbleBackground() -> some View {
        self.padding()
            .background {
                RoundedRectangle(cornerRadius: 10)
                    .foregroundColor(.primary)
                    .opacity(0.4)
            }
    }
}

struct OverlayView_Previews: PreviewProvider {
    static var previews: some View {
        OverlayView(count: 3.0) { }
            .background(Color.red.opacity(0.4))

    }
}
