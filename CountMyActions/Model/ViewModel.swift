/*
See LICENSE folder for this sample’s licensing information.

Abstract:
The app's main view model.
*/

import SwiftUI
import CreateMLComponents
import AsyncAlgorithms

/// - Tag: ViewModel
class ViewModel: ObservableObject {

    /// The full-screen view that presents the pose on top of the video frames.
    @Published var liveCameraImageAndPoses: (image: CGImage, poses: [Pose])?

    /// The user-visible value of the repetition count.
    var uiCount: Float = 0.0
    var currentAlphabet = "B"
    private var displayCameraTask: Task<Void, Error>?

    private var predictionTask: Task<Void, Error>?

    /// Stores the predicted action repetition count in the last window.
    private var lastCumulativeCount: Float = 0.0

    /// An asynchronous channel to divert the pose stream for another consumer.
    private let poseStream = AsyncChannel<TemporalFeature<[Pose]>>()
    
    /// A Create ML Components transformer to extract human body poses from a single image or a video frame.
    /// - Tag: poseExtractor
    private let poseExtractor = HumanHandPoseExtractor()
    
    /// The camera configuration to define the basic camera position, pixel format, and resolution to use.
    private var configuration = VideoReader.CameraConfiguration()
    
    /// The counter to count action repetitions from a pose stream.
    private let actionCounter = ActionCounter()

// MARK: - View Controller Events

    /// Configures the main view after it loads.
    /// Starts the video-processing pipeline.
    func initialize() {
        startVideoProcessingPipeline()
    }

    // Getting the distance of one CGPoint to another
    func distance(from point1: CGPoint, to point2: CGPoint) -> CGFloat {
        return hypot(point1.x - point2.x, point1.y - point2.y)
    }
    
    // Find how similar two arrays are which are also the same length
    func findDistanceSimilarity(distances: [CGFloat], goalDistances: [CGFloat]) -> CGFloat {
        //let threshold: CGFloat = 0.025
        var totalDifference: CGFloat = 0

        if distances.count != goalDistances.count {
            print("Arrays have different sizes!")
            return 1
        } else {
            for i in 0..<distances.count {
                totalDifference += abs(distances[i] - goalDistances[i])
            }
            
            let averageDifference = totalDifference / CGFloat(distances.count)
            //print(averageDifference)
            
            return averageDifference
        }
    }
    
    // Are the two arrays similar enough?
    func passesThresholdTest(average: CGFloat, threshold: CGFloat) -> Bool {
        return average <= threshold
    }
// MARK: - Button Events

    /// Toggles the view between the front- and back-facing cameras.
    func onCameraButtonTapped() {
        toggleCameraSelection()

        // Reset the count.
        uiCount = 0.0

        // Restart the video processing.
        startVideoProcessingPipeline()
    }

// MARK: - Helper methods

    /// Change the camera toggle positions.
    func toggleCameraSelection() {
        if configuration.position == .front {
            configuration.position = .back
        } else {
            configuration.position = .front
        }
    }
    
    /// Start the video-processing pipeline by displaying the poses in the camera frames and
    /// starting the action repetition count prediction stream.
    func startVideoProcessingPipeline() {

        if let displayCameraTask = displayCameraTask {
            displayCameraTask.cancel()
        }

        displayCameraTask = Task {
            // Display poses on top of each camera frame.
            try await self.displayPoseInCamera()
        }

        if predictionTask == nil {
            predictionTask = Task {
                // Predict the action repetition count.
                try await self.predictCount()
            }
        }
    }

    /// Display poses on top of each camera frame.
    func displayPoseInCamera() async throws {
        // Start reading the camera.
        let frameSequence = try await VideoReader.readCamera(
            configuration: configuration
        )
        var lastTime = CFAbsoluteTimeGetCurrent()

        for try await frame in frameSequence {

            if Task.isCancelled {
                return
            }

            // Extract poses in every frame.
            let poses = try await poseExtractor.applied(to: frame.feature)

            // Send poses into another pose stream for additional consumers.
            await poseStream.send(TemporalFeature(id: frame.id, feature: poses))

            // Calculate poses from the image frame and display both.
            if let cgImage = CIContext()
                .createCGImage(frame.feature, from: frame.feature.extent) {
                if let firstPose = poses.first {
                    if currentAlphabet == "A" {
                        guard
                            let thumbTipLocation = firstPose.keypoints[.thumbTip]?.location,
                            let indexMCP = firstPose.keypoints[.indexMCP]?.location,
                            let indexTip = firstPose.keypoints[.indexTip]?.location,
                            let indexPIP = firstPose.keypoints[.indexPIP]?.location,
                            let middleTip = firstPose.keypoints[.middleTip]?.location,
                            let middleMCP = firstPose.keypoints[.middleMCP]?.location,
                            let ringTip = firstPose.keypoints[.ringTip]?.location,
                            let ringMCP = firstPose.keypoints[.ringMCP]?.location,
                            let littleTip = firstPose.keypoints[.littleTip]?.location,
                            let littleMCP = firstPose.keypoints[.littleMCP]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocation, indexMCP, indexTip, indexPIP, middleTip, middleMCP, ringTip, ringMCP, littleTip, littleMCP]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.2076987420531851, 0.1835510257779297, 0.16406051468816937, 0.2558614507829218, 0.280592152320913, 0.3218281527293722, 0.36494620320818766, 0.3809252664749478, 0.452110328269461, 0.05040980171677795, 0.053710630408112026, 0.07042710651252222, 0.07297317544010236, 0.12925169524069216, 0.15748249845457485, 0.18355851065703155, 0.24511493949892774, 0.07115454264631857, 0.07231499790556312, 0.10837209662881106, 0.13829105947927142, 0.18832440883710277, 0.19739506061386006, 0.2728018006554401, 0.12179556919918844, 0.12301714695418015, 0.1828513024791116, 0.20680366464342495, 0.2371329761263118, 0.29477577148101963, 0.06118142948503389, 0.06605397770155608, 0.12383661305750096, 0.12508339861906487, 0.2038941362726299, 0.07807341851002031, 0.08453157684623332, 0.12008102643270012, 0.1723134943656224, 0.08202293871693597, 0.0594671803236903, 0.14628532049132342, 0.07072025372321902, 0.08797402116340759, 0.09609673290512083]

                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.025)) {
                            print(String(format: "Frame rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
                            
                        }
                        }
                    if currentAlphabet == "B" {
                        guard
                            let thumbTipLocationB = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCB = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPB = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPB = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPB = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPB = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPB = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipB = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPB = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPB = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPB = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipB = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPB = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPB = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPB = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipB = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPB = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPB = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPB = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipB = firstPose.keypoints[.littleTip]?.location
                        else {
                            return
                        }
                            
                        let keypoints: [CGPoint] = [thumbTipLocationB, thumbCMCB, thumbMPB, thumbIPB, indexMCPB, indexPIPB, indexDIPB, indexTipB, middleMCPB, middlePIPB, middleDIPB, middleTipB, ringMCPB, ringPIPB, ringDIPB, ringTipB, littleMCPB, littlePIPB, littleDIPB, littleTipB]
                        
                        var distances: [CGFloat] = []
                        let goalDistances: [CGFloat] = [0.20215525373419044, 0.20482293957650743, 0.1368610284675483, 0.1649523633071689, 0.2040070008827305, 0.23868453482552876, 0.2810380899982097, 0.09692556068444079, 0.1630496583950333, 0.20463317021862212, 0.23239412728541076, 0.03638603647968374, 0.0993985505594013, 0.14560214051145282, 0.17751393538071825, 0.04011497206444402, 0.0350994096533039, 0.07591643532992783, 0.11965984408091293, 0.09828000095814109, 0.15374527986230235, 0.1687084080058388, 0.23183000152473957, 0.2828694373073143, 0.32463912235410286, 0.17208474781376815, 0.24262861425679444, 0.29600612861794334, 0.33401523606801914, 0.18475606210434042, 0.24422343715251443, 0.29149288344142094, 0.32663081213557615, 0.21178941424895784, 0.23595135830565492, 0.2679046017059374, 0.3028059777382492, 0.09236082041233454, 0.09074137826565748, 0.14541058461988612, 0.19480085366654692, 0.2334342900179642, 0.13058914577061687, 0.17270456621041802, 0.2213292424324632, 0.258857047592483, 0.1738449056432714, 0.2029613915923602, 0.2406397216748935, 0.2724873989510516, 0.23088297424146526, 0.23102053344517823, 0.2487243745996808, 0.27180344350494795, 0.030070301921303947, 0.08901057633238793, 0.13805085711947251, 0.18264650718523823, 0.043618791041042854, 0.08892375050745874, 0.1423157983676555, 0.18028742347608442, 0.10087912846632562, 0.11117649368114338, 0.14866622606842733, 0.1813840913775721, 0.17216872827494756, 0.15429154890786198, 0.16277986388749396, 0.18103897808371755, 0.06440403717977154, 0.11525656858138784, 0.15875207971379451, 0.06879391617474115, 0.08203069908329802, 0.13127314742586627, 0.1691441078112947, 0.12864079843444512, 0.12520471061665706, 0.15462757092575186, 0.1843057754201714, 0.20125330429588187, 0.17973285600034805, 0.18330781670184726, 0.1959110661787824, 0.05107963332969083, 0.09439067508073236, 0.11066705619261592, 0.05796018887504203, 0.08416912028174288, 0.11845550297094214, 0.1687196322013219, 0.13250317484785126, 0.1399058597620546, 0.15989149933315924, 0.24339338834435087, 0.20906880631566305, 0.19892237523888365, 0.19683484083446304, 0.04495107298962156, 0.15235966586987418, 0.07641376841261101, 0.06380029136578853, 0.08556828895106913, 0.2055574150634709, 0.15269089170407565, 0.1422482379569742, 0.15104041075997904, 0.2787739966833697, 0.23740334798764384, 0.21860217427948567, 0.205936049136433, 0.19696968135836068, 0.11799015684283082, 0.08851047647912877, 0.09187978351335274, 0.24881238112021645, 0.19077899863402245, 0.17162095859435875, 0.1721578861828443, 0.32114631468639243, 0.27732583161076446, 0.2547887143543967, 0.23660546759362988, 0.08471181846499493, 0.13727733760856273, 0.17302749303682452, 0.06055706896120619, 0.07451324810267472, 0.1195008939560086, 0.15454650524672547, 0.13469435859415066, 0.11121818007221228, 0.11973026896463085, 0.14141522613054588, 0.0540797878767629, 0.09166230103240515, 0.13122251581562958, 0.07784298612335086, 0.0825952511184175, 0.10624478673120626, 0.20316018081687048, 0.16103876209576545, 0.1446030621499901, 0.1391019190826987, 0.03808146913433976, 0.17675060850056268, 0.10780528227057094, 0.08311096126239621, 0.08739442734315385, 0.24403663550121152, 0.1952306635187421, 0.16836649494540895, 0.14810070953034052, 0.20748624556569095, 0.13316867340480618, 0.09580362484637103, 0.08482753995037212, 0.27070347922240184, 0.21859852265984542, 0.1863291787158853, 0.1579690774193759, 0.07860517784859396, 0.12889392090799848, 0.16347121907610662, 0.07472518703277005, 0.05718932127701171, 0.08315009116030185, 0.12024667955627884, 0.050827926127942416, 0.08619485776743924, 0.13756091635358036, 0.08746450528448634, 0.06681694954520762, 0.07072209238474601, 0.035647382323338674, 0.18107384700805698, 0.12602701146018871, 0.09075792243749523, 0.06499854718640076, 0.21094016100403765, 0.15444545424592965, 0.11463699249310262, 0.07758491172388698, 0.05708218521093277, 0.1004814179072935, 0.14524772107131892, 0.04391129149693968, 0.08877015149059482, 0.04487080878881656]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.025)) {
                            print(String(format: "Frame rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
                        }
                        
                    }
                }
                await display(image: cgImage, poses: poses)
            }
            
            
            // Frame rate debug information.
            //print(String(format: "Frame rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
            lastTime = CFAbsoluteTimeGetCurrent()
        }
    }
    
    /// Predict the action repetition count.
    func predictCount() async throws {
        // Create an asynchronous temporal sequence for the pose stream.
        let poseTemporalSequence = AnyTemporalSequence<[Pose]>(poseStream, count: nil)

        // Apply the repetition-counting transformer pipeline to the incoming pose stream.
        let finalResults = try await actionCounter.count(poseTemporalSequence)

        var lastTime = CFAbsoluteTimeGetCurrent()
        for try await item in finalResults {

            if Task.isCancelled {
                return
            }

            let currentCumulativeCount = item.feature
            // Observe each predicted count (cumulative) and compare it to the previous result.
            if currentCumulativeCount - lastCumulativeCount <= 0.001 {
                // Reset the UI counter to 0 if the cumulative count isn't increasing.
                uiCount = 0.0
            }

            // Add the incremental count to the UI counter.
            uiCount += currentCumulativeCount - lastCumulativeCount

            // Counter debug information.
            /**
            print("""
                    Cumulative count \(currentCumulativeCount), last count \(lastCumulativeCount), \
                    incremental count \(currentCumulativeCount - lastCumulativeCount), UI count \(uiCount)
                    """)
             */
            
            // Update and store the last predicted count.
            lastCumulativeCount = currentCumulativeCount

            // Prediction rate debug information.
            //print(String(format: "Count rate %2.2f fps", 1 / (CFAbsoluteTimeGetCurrent() - lastTime)))
            lastTime = CFAbsoluteTimeGetCurrent()
        }
    }

    /// Updates the user interface's image view with the rendered poses.
    /// - Parameters:
    ///   - image: The image frame from the camera.
    ///   - poses: The detected poses to render onscreen.
    /// - Tag: display
    @MainActor func display(image: CGImage, poses: [Pose]) {
        self.liveCameraImageAndPoses = (image, poses)
    }
}
