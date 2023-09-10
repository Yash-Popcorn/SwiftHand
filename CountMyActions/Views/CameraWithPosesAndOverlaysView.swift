/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's camera with poses and the overlay view.
*/

import SwiftUI

struct CameraWithPosesAndOverlaysView: View {

    var theString = "A"
    @StateObject var viewModel = ViewModel()

    var body: some View {
        OverlayView(count: viewModel.uiCount, theString: theString) {
            viewModel.onCameraButtonTapped()
        }
        .background {
            if let (image, poses) = viewModel.liveCameraImageAndPoses {
                CameraView(
                    cameraImage: image
                )
                .overlay {
                    PosesView(poses: poses)
                }
                .ignoresSafeArea()
            }
        }
        .onAppear {
            viewModel.currentAlphabet = theString
            viewModel.initialize()
        }
    }
}

struct CameraWithOverlaysView_Previews: PreviewProvider {
    static var previews: some View {
        CameraWithPosesAndOverlaysView()
    }
}
