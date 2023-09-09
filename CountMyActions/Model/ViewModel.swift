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
    var uiCount: Float = 0.055
    var currentAlphabet = "Please"
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
                            uiCount += 1
                            
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
                            uiCount += 1
                        }
                        
                    }
                    
                    if currentAlphabet == "Yes" {
                        guard
                            let thumbTipLocationYes = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCYes = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPYes = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPYes = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPYes = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPYes = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPYes = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipYes = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPYes = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPYes = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPYes = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipYes = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPYes = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPYes = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPYes = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipYes = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPYes = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPYes = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPYes = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipYes = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationYes, thumbCMCYes, thumbMPYes, thumbIPYes, indexMCPYes, indexPIPYes, indexDIPYes, indexTipYes, middleMCPYes, middlePIPYes, middleDIPYes, middleTipYes, ringMCPYes, ringPIPYes, ringDIPYes, ringTipYes, littleMCPYes, littlePIPYes, littleDIPYes, littleTipYes]
                        var distances: [CGFloat] = []
                        let goalDistances: [CGFloat] = [0.11295749327227306, 0.05694801567107017, 0.030764673874984744, 0.1631694175250284, 0.08971149870720055, 0.058536428895486985, 0.0562870930549566, 0.1814960175641534, 0.06360249175502959, 0.06848270057734718, 0.0634340845515916, 0.20071899165858, 0.12756497673873482, 0.12492606234127329, 0.12074160197680144, 0.24317447040506293, 0.19600386692814284, 0.18801334213414453, 0.1745091504863062, 0.060020050855689434, 0.13529000710268704, 0.1909579254237917, 0.15350282652401173, 0.1389778507249656, 0.13568788033648718, 0.1543184112624793, 0.0523763513606776, 0.04453362067005868, 0.061431485521227264, 0.13260157779926518, 0.045653789555997734, 0.01902241806746273, 0.01959544129096795, 0.14083309833382254, 0.08762569812548548, 0.07519236006731539, 0.0642364374576687, 0.07565188846198082, 0.15333475319810283, 0.09966078005921888, 0.08039623509958062, 0.07708705126885897, 0.14453423679273109, 0.007645743226321861, 0.02172091655365391, 0.01174052061260835, 0.1500050956645572, 0.07105566864016606, 0.06907106583202026, 0.06450947910740737, 0.18634014451812406, 0.1393227981864755, 0.13468472755041516, 0.12407866971051866, 0.14349541992764117, 0.06630966279794272, 0.034421790284084625, 0.033465961302702074, 0.17535170606163733, 0.08319425691374831, 0.09222229141922862, 0.07801629491379883, 0.20457814524967194, 0.14137883130260817, 0.14450663761690116, 0.1397344313599838, 0.2566621660820267, 0.2133284128615543, 0.21027070309666163, 0.19872988464267435, 0.07793687662554256, 0.1091174329999296, 0.1100826881942579, 0.08445795346238615, 0.15749454788773481, 0.17356490095783492, 0.14319729950746, 0.14888137392803147, 0.15844980675014372, 0.18433481703552218, 0.17913550291204222, 0.23353161800672237, 0.21940713568672476, 0.24293631831116197, 0.2449937065120993, 0.03204675180052801, 0.03369685407572784, 0.12676917775263932, 0.10623495129684003, 0.12134567520628939, 0.09352940697725143, 0.17300827489577528, 0.1385419836840253, 0.15466105172581293, 0.1491379414684842, 0.24289355354769274, 0.21129500803547943, 0.22140455380840443, 0.21627245728164163, 0.003309621328242894, 0.14694513670576081, 0.0877923812329591, 0.10107116888452365, 0.07758438116591226, 0.18394368278051093, 0.1336433455712379, 0.14388000776820645, 0.13856903428263265, 0.24517087155741774, 0.20738158694907366, 0.21129491685564128, 0.20313812316779808, 0.1459249736593114, 0.08448284762589785, 0.09777533743140943, 0.07430327210813371, 0.18192908427436658, 0.1306594135043836, 0.14066567897925614, 0.13536395331105924, 0.24247374157612125, 0.2043803290002363, 0.20807227381951446, 0.19985531354975086, 0.14460257310473848, 0.15783918002550418, 0.1328190159434126, 0.06647466730679157, 0.11055923562372917, 0.14059242689591855, 0.136793133811078, 0.15357535726767907, 0.15098983522759263, 0.18350003106882568, 0.19201115080166095, 0.016114341354011772, 0.014298612569765168, 0.1466916943812165, 0.06546741830116921, 0.061764433127836256, 0.05732803808441797, 0.18016872482496957, 0.13241845368587765, 0.1270977928565492, 0.11643756777748125, 0.030397235352771876, 0.15469325559450592, 0.06922145937248692, 0.05813285545002532, 0.05475979242325191, 0.1804139209243443, 0.1299039950343565, 0.11953202065959648, 0.1066450199129586, 0.13991783206950506, 0.06444333928897726, 0.06729217017546604, 0.06224945905899411, 0.18023687244394948, 0.1353330805790126, 0.13431486792843203, 0.12555404525863476, 0.08831668177060302, 0.11443009544414887, 0.11300692182540505, 0.08742840727524906, 0.09530135686854448, 0.13452924936349103, 0.14873973420957992, 0.030060334274362208, 0.026676254814581652, 0.11579515508114648, 0.07375797355713214, 0.08554516131240851, 0.08667063084050843, 0.005542292989656202, 0.1232898724759466, 0.07177129692515524, 0.06743663546496718, 0.06224337542104221, 0.12588015851029302, 0.07544405018087784, 0.07281492326443724, 0.06776636816849518, 0.05583305781494484, 0.0937101163811253, 0.11571472540273134, 0.04275601487065345, 0.06258137451010079, 0.022573740409365363]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1                        }
                    
                    }
                    
                    if currentAlphabet == "No" {
                        guard
                            let thumbTipLocationNo = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCNo = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPNo = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPNo = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPNo = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPNo = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPNo = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipNo = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPNo = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPNo = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPNo = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipNo = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPNo = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPNo = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPNo = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipNo = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPNo = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPNo = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPNo = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipNo = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing6
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationNo, thumbCMCNo, thumbMPNo, thumbIPNo, indexMCPNo, indexPIPNo, indexDIPNo, indexTipNo, middleMCPNo, middlePIPNo, middleDIPNo, middleTipNo, ringMCPNo, ringPIPNo, ringDIPNo, ringTipNo, littleMCPNo, littlePIPNo, littleDIPNo, littleTipNo]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.08338058018500848, 0.03866435840603527, 0.007450363954493826, 0.06726603406987273, 0.06482336007697038, 0.049831038006056774, 0.024918653494249918, 0.10596889612508721, 0.08193990334938878, 0.041063785309141294, 0.01159753943842365, 0.15047112331040488, 0.12209115344995657, 0.09552714732153396, 0.10896672780218153, 0.18735034754938065, 0.16830915031967986, 0.13114248549306845, 0.12843557864749908, 0.04477884133607698, 0.08810435409681437, 0.10438162114875732, 0.12933058848245416, 0.12497513072522001, 0.1078972154091873, 0.1048516204565215, 0.10604255352137441, 0.08425927500881215, 0.07562781874825981, 0.11765114977430985, 0.10380285347897354, 0.05166274676183799, 0.03716017195440771, 0.1357829458993987, 0.12608636678581653, 0.08091795577760365, 0.06204854592777694, 0.043369899225648156, 0.07724483381979347, 0.09196523038009616, 0.08336756278365104, 0.06338137281777088, 0.09852005862473118, 0.08571553749975837, 0.050962238926108024, 0.031975248368452294, 0.13120975671515314, 0.10768580422530517, 0.06763340561684256, 0.07337928130319159, 0.1613978900783276, 0.14572319316475957, 0.10386801786676698, 0.09527729351166535, 0.07353238163743538, 0.06791752699312686, 0.05096268363679243, 0.022708603118239537, 0.1132297397651998, 0.08863246337876951, 0.04794720085409595, 0.01900809996619804, 0.15791909018212807, 0.1295206924335213, 0.10256291596218271, 0.11505202488178906, 0.19465163067049554, 0.17571670200380013, 0.1383124396829712, 0.1350113160242131, 0.03868874627315768, 0.05285621889960622, 0.06807844036784787, 0.04947128176824537, 0.017409971409297786, 0.02776231293457849, 0.05916101061964808, 0.10378419565246778, 0.07216543974336061, 0.07848526280277941, 0.10757076637401404, 0.14885361933871671, 0.12524858322479698, 0.10262424325181699, 0.11506458879357094, 0.022557427447930073, 0.05127741248262713, 0.08693062058318334, 0.054105145028743834, 0.045383185696295604, 0.06303332121048574, 0.1419273141689312, 0.11032601690694256, 0.11388910886983138, 0.14027981963660155, 0.18745198379205272, 0.16362495360409593, 0.14074426039707075, 0.15098073393498698, 0.030939426126611845, 0.1022906635211153, 0.07003375448923915, 0.046792720142499265, 0.05176399233637104, 0.15598382548868225, 0.12449579347226149, 0.11890024651399123, 0.14171831665531534, 0.19979463317284396, 0.17698946117198064, 0.14942581091136778, 0.15570570838237052, 0.11389447711114285, 0.08500538893674359, 0.04849481778091958, 0.03274653959154627, 0.1633522932753224, 0.13316086797145274, 0.11465966804719685, 0.13149135204673768, 0.20343870341100526, 0.18271830506953826, 0.14893258410932786, 0.14941797166770324, 0.032836190485481496, 0.06612841764239094, 0.09523131633757333, 0.05523067324273624, 0.02402455231124307, 0.05862861118251915, 0.09044478585643158, 0.10184634908210972, 0.07725772667436284, 0.0652775650627929, 0.08696382602236985, 0.040972873564044957, 0.07271586843098404, 0.08787119768115517, 0.056321455548824416, 0.07201272721195966, 0.1031068005286018, 0.13385817865011415, 0.10969501090641491, 0.09108122827363661, 0.10696002856483686, 0.031827548329784135, 0.11493903620963633, 0.08467488796150974, 0.07211157364572346, 0.09585695894732621, 0.15606541340964292, 0.13463712551232962, 0.10348278372739417, 0.10893378362940882, 0.13894477891554133, 0.1107735421448163, 0.08423374671856959, 0.09895722486701491, 0.17578466155771608, 0.15671487712279134, 0.11968837966074658, 0.11769937487065932, 0.031626343688370626, 0.0670405919206616, 0.08722357275508633, 0.047477158102695344, 0.02225172294211769, 0.04084570998490573, 0.06926884833029529, 0.05271539412236235, 0.08140880422070876, 0.07782877187274768, 0.053383284454545855, 0.046187742167111204, 0.07188617517013092, 0.032097136273117007, 0.09380438656237652, 0.07877180871433075, 0.03634898509971923, 0.03711537360934818, 0.09931447043163988, 0.09197117805912337, 0.04733126257285017, 0.024918491427065377, 0.02540032039053543, 0.0575396501617823, 0.07483467502794093, 0.04519072640251806, 0.06993269764003746, 0.02862767547734399]

                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1

                        }
                    }
                    
                    if currentAlphabet == "I Love You" {
                        guard
                            let thumbTipLocationILY = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCILY = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPILY = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPILY = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPILY = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPILY = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPILY = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipILY = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPILY = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPILY = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPILY = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipILY = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPILY = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPILY = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPILY = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipILY = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPILY = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPILY = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPILY = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipILY = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationILY, thumbCMCILY, thumbMPILY, thumbIPILY, indexMCPILY, indexPIPILY, indexDIPILY, indexTipILY, middleMCPILY, middlePIPILY, middleDIPILY, middleTipILY, ringMCPILY, ringPIPILY, ringDIPILY, ringTipILY, littleMCPILY, littlePIPILY, littleDIPILY, littleTipILY]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.39846305731484255, 0.2616237057209268, 0.13372229698939495, 0.3528089869532724, 0.3422480349040673, 0.3522454453203953, 0.36760342340132146, 0.4448639103273463, 0.4159517321312209, 0.39629935049016746, 0.4047563062586695, 0.5203808214100969, 0.48361644621867544, 0.4631384894997506, 0.4616604146051636, 0.5852297613835826, 0.5930415891845143, 0.6029623862903511, 0.5983694698914573, 0.1375961990598991, 0.2655342463731288, 0.17234847886450497, 0.26833582517812726, 0.3230023097426844, 0.37039568457599287, 0.18128208630558856, 0.2108175946137092, 0.12899515983914653, 0.08043472228385744, 0.21584095881097276, 0.20444149403580408, 0.13873763221403426, 0.09997154682697908, 0.2554181093889015, 0.29575943798768073, 0.33166461905324823, 0.3596099425755651, 0.12816891115175266, 0.15183697257599135, 0.21570280677788511, 0.26283188131414364, 0.3058351873251658, 0.22298773148782625, 0.21941513226055845, 0.1621477012899043, 0.1517824975255322, 0.2887451478312739, 0.25984451266858155, 0.21834182252679918, 0.20555340076929907, 0.3465373487959251, 0.36947678411906865, 0.39283486619289437, 0.4051891415955509, 0.23234327967689714, 0.24791126004454717, 0.2753737390287698, 0.30537787650381576, 0.3213165009026118, 0.2998715432696707, 0.26816478352920775, 0.2722627076741173, 0.3948660179241424, 0.36018415410331484, 0.3330621123948593, 0.32873258487835105, 0.4579227286594844, 0.4710673353729323, 0.48606914262538936, 0.48797369652898476, 0.09735168931276081, 0.15200726998274802, 0.19939060891606794, 0.09270495870964483, 0.06936879220691554, 0.06272334623218682, 0.1065980250535687, 0.1691193107332803, 0.1310767643566915, 0.12790693865259303, 0.1526904678869166, 0.23554472046266797, 0.24033523696157746, 0.2537446989710921, 0.25838860602578706, 0.054749976024815177, 0.10218357417707799, 0.15739894335416482, 0.10658388227150911, 0.15611864643405518, 0.20349334546683423, 0.22641276590328327, 0.18640041634209228, 0.21157844228362402, 0.24520307004926792, 0.29193654071971803, 0.2774305153038849, 0.27418719533259206, 0.2604218596788409, 0.047434053183592124, 0.2036456343667342, 0.15100400754390356, 0.20958977007853083, 0.2577999649504074, 0.2665365704825517, 0.2278403413696905, 0.2614249919369246, 0.2976600189570049, 0.32943443558889646, 0.30686424244652705, 0.29581746993252156, 0.2732740070039163, 0.24643457664288707, 0.19370175504708656, 0.25630901473491147, 0.30495032426655255, 0.30484394580082297, 0.2674958712494776, 0.30587825578685623, 0.34362164076928203, 0.3652838283859955, 0.33730258248077993, 0.3207626138649746, 0.2920986951023436, 0.052767212780835585, 0.062382309372986576, 0.101156695562136, 0.0765159260559531, 0.03890147337209603, 0.06285733839290455, 0.10910271259356759, 0.1432955870261587, 0.1498157010787995, 0.16984839974796764, 0.18569605334923106, 0.08182266884681992, 0.13200647142662403, 0.12025881094507225, 0.08003232956637762, 0.11331100632344478, 0.15561501715713918, 0.18657171983347795, 0.17954960535998887, 0.18721049023581374, 0.1891402392192043, 0.051136185429861425, 0.12782876302423332, 0.0977900900833534, 0.06892802667779684, 0.09011260486003758, 0.18975873047126623, 0.20752590777904092, 0.23136817745234378, 0.2479526406020218, 0.14575626970621094, 0.12739274650640792, 0.06940083896813272, 0.057503221680156334, 0.19706236043149195, 0.22775524054639315, 0.2590367660417704, 0.28286761103227737, 0.04030850286563889, 0.07766824386772538, 0.11953545019889918, 0.06705204589061214, 0.08205280593899948, 0.11599355221682611, 0.14922721876732686, 0.06926527616735757, 0.11790087560744635, 0.10713679616551114, 0.11108126362835016, 0.13392703990150906, 0.1555593692500703, 0.04894246664120447, 0.1283539808282053, 0.15913366178831106, 0.19303850408677192, 0.2217770216939601, 0.15552401991842338, 0.1969949896677644, 0.23523423272883906, 0.26762702598065613, 0.059125485703185404, 0.10616273416501161, 0.15362822703772142, 0.04703813273505627, 0.09527809344241253, 0.05002313054821613]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1

                        }
                        
                    }
                    
                    if currentAlphabet == "Bathroom" {
                        guard
                            let thumbTipLocationBathroom = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCBathroom = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPBathroom = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPBathroom = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPBathroom = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPBathroom = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPBathroom = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipBathroom = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPBathroom = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPBathroom = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPBathroom = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipBathroom = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPBathroom = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPBathroom = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPBathroom = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipBathroom = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPBathroom = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPBathroom = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPBathroom = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipBathroom = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationBathroom, thumbCMCBathroom, thumbMPBathroom, thumbIPBathroom, indexMCPBathroom, indexPIPBathroom, indexDIPBathroom, indexTipBathroom, middleMCPBathroom, middlePIPBathroom, middleDIPBathroom, middleTipBathroom, ringMCPBathroom, ringPIPBathroom, ringDIPBathroom, ringTipBathroom, littleMCPBathroom, littlePIPBathroom, littleDIPBathroom, littleTipBathroom]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.18239697058317234, 0.1022132972469995, 0.04132187594396626, 0.059848752819495955, 0.021483622729954105, 0.041313157299150985, 0.09119665869365032, 0.1192836362526891, 0.067203761662015, 0.11113936678730771, 0.15738094557840177, 0.17488032900458686, 0.1279058720058544, 0.15793325897227686, 0.19478800660617127, 0.24635777078159501, 0.20661667291206903, 0.19744289153700706, 0.22241626254515864, 0.11336325773792352, 0.14423415360680897, 0.12940253362822457, 0.1821708812335535, 0.14764615516115315, 0.0959760113467746, 0.14297996118067896, 0.13787783045204155, 0.07304317106991846, 0.025274649109085796, 0.1624604488576204, 0.12676276341176, 0.07422632673379824, 0.04286618127981079, 0.19588175838879401, 0.1728228972705814, 0.12050879912285434, 0.09900835953026482, 0.06297969928084603, 0.08589959272707719, 0.09054622857636825, 0.061172846995024704, 0.03658435709311013, 0.15113629311651466, 0.10588385556969687, 0.07447834447584765, 0.09058883604210313, 0.1997275168581505, 0.14639722810213562, 0.13513544428778468, 0.14506669591608612, 0.25991176927614296, 0.22474025560375405, 0.19024577204181933, 0.19302892234207275, 0.0407861582901632, 0.03807755344428543, 0.00657471914534936, 0.05037325378896132, 0.11315180354124675, 0.05866184923828268, 0.07635898320251977, 0.11897847798152011, 0.16821588523306127, 0.11584657552892524, 0.13122784877006416, 0.16143015298509542, 0.23665857152869732, 0.1979447768481694, 0.1780952082259496, 0.19591830030227259, 0.0698499331789355, 0.04735992204811257, 0.05564173909054173, 0.07263944904523123, 0.020217843262657215, 0.056366392867684474, 0.10565439213608359, 0.12744152386857435, 0.07519917153311223, 0.09809604423302345, 0.13636289231872098, 0.19607275725675063, 0.15721705493637947, 0.14004520001185025, 0.16268279741411013, 0.034655348883179886, 0.08725614294789936, 0.1359174646222943, 0.08171138737440103, 0.11410687148044682, 0.15689953694083753, 0.1918494316078847, 0.1426746773475062, 0.16645880462872942, 0.1991072081428679, 0.26267150401238243, 0.22312017186401503, 0.2098427755513669, 0.23132447357546163, 0.05263556107606264, 0.11968816899367224, 0.06510434888936556, 0.08113571802819981, 0.12237167430074841, 0.17478571735314868, 0.12241410796065832, 0.1370129845373418, 0.16613930108145153, 0.24321678282925055, 0.20451675800778743, 0.18437461266723984, 0.20159653260792718, 0.11535072602099224, 0.07425050654761219, 0.03991407459827439, 0.07083293443957796, 0.16315469949644634, 0.10990909212362168, 0.10147376052026112, 0.1194802349860967, 0.22380827886578192, 0.18827380452585138, 0.1554672936394926, 0.16245368519196607, 0.05510267978373, 0.08867394360003812, 0.1276130185902092, 0.05594885755494638, 0.018408918752442268, 0.0762933202390157, 0.12683433297590668, 0.12707600704924946, 0.0873567994699809, 0.08762664154962053, 0.1258365374894342, 0.06648187564760132, 0.11566579989845695, 0.11088238083981586, 0.06104404047622164, 0.09525610082245012, 0.13870922656455262, 0.18108621963480173, 0.1416740656417137, 0.13040737730206267, 0.15806151917483158, 0.04952061241611384, 0.12928233239680287, 0.07854694949489881, 0.061561270558301275, 0.08507117222985858, 0.18585773764413696, 0.15180870541546707, 0.1158826485416842, 0.123386085227258, 0.15487640519802237, 0.11302028890959373, 0.06837831029360932, 0.0561095872359972, 0.19698196426515233, 0.1696868872002181, 0.12141875321561857, 0.10942118656401147, 0.05377006317305957, 0.08827167430359506, 0.1324214770812789, 0.07194309104257855, 0.03225879707152705, 0.06033245646349688, 0.10678996022709604, 0.05814974306964166, 0.10871964082596745, 0.12087617361226263, 0.08214719365613027, 0.07240735725816361, 0.10827874998075096, 0.05057002597677675, 0.13000577965744187, 0.1013104485145028, 0.055983234970017386, 0.06486700898001056, 0.15605706546910553, 0.13708955995915065, 0.08234770008753435, 0.05614288012227065, 0.03979240792515392, 0.07573158779160649, 0.10724214568109289, 0.05550285325616168, 0.09887395974555754, 0.04650393158319388]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    
                    if currentAlphabet == "Bored" {
                        guard
                            let thumbTipLocationBored = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCBored = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPBored = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPBored = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPBored = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPBored = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPBored = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipBored = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPBored = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPBored = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPBored = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipBored = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPBored = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPBored = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPBored = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipBored = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPBored = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPBored = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPBored = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipBored = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationBored, thumbCMCBored, thumbMPBored, thumbIPBored, indexMCPBored, indexPIPBored, indexDIPBored, indexTipBored, middleMCPBored, middlePIPBored, middleDIPBored, middleTipBored, ringMCPBored, ringPIPBored, ringDIPBored, ringTipBored, littleMCPBored, littlePIPBored, littleDIPBored, littleTipBored]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.11057348700641038, 0.07669471615458068, 0.033576389497445396, 0.13955743369778179, 0.1050749055157626, 0.10270577836212573, 0.11105012633140855, 0.14225900886771745, 0.038105990921813375, 0.03408790906183256, 0.06714177815019537, 0.13336245305676245, 0.025681275957424626, 0.04278546770248748, 0.07701916363516975, 0.11813747758842724, 0.030032038492818235, 0.05763553564581899, 0.08660667535722252, 0.040153333735001316, 0.08451716198480351, 0.08153082752970799, 0.12078890222561013, 0.1491812923521318, 0.17484806563588223, 0.08153244833705436, 0.11410737203938924, 0.08528540684223547, 0.051108760628614934, 0.07004302889851478, 0.10097657903377918, 0.06848060365825268, 0.034782555599362816, 0.05115564155264997, 0.08553207166510744, 0.05294125173748553, 0.025072865901575536, 0.04651366006639249, 0.0745011876271402, 0.08714239414112059, 0.11144063927101851, 0.13576472935062797, 0.07619043338894636, 0.07440271193046577, 0.0469908109742487, 0.011121448249307355, 0.06508290554278921, 0.0626151106442368, 0.03432684612046354, 0.01039300733779895, 0.04606907635161373, 0.048422435673579615, 0.024916477582735942, 0.01632338658088206, 0.10602273668686248, 0.07985398282866346, 0.08811743614724163, 0.10499509743587143, 0.10870014889747297, 0.03184468090297371, 0.001592907586425191, 0.03585165784921771, 0.09980322478326697, 0.01647009129718014, 0.018891668100130356, 0.049734708916255324, 0.08497874937066403, 0.004272297189559614, 0.035039095038984114, 0.05947769179554037, 0.07576655133245208, 0.11295305891790405, 0.14290830975594415, 0.003446570984256423, 0.11858696194615281, 0.10546955492295271, 0.07832448933602748, 0.011506804734743857, 0.11701978618316611, 0.10356728850952802, 0.08244662750523304, 0.031222185971701642, 0.10979375427661911, 0.09903568790014934, 0.07966410295952375, 0.03725201982553997, 0.06720655435190695, 0.07917177246102058, 0.06966558603471504, 0.07839935405540754, 0.08059220948179173, 0.07921296269664015, 0.07960132388701732, 0.09149910690405574, 0.09731198303626189, 0.08180881534782294, 0.08395123018385246, 0.09961403588873795, 0.10244248912044787, 0.02996066721079029, 0.11636934809059328, 0.06469225774731478, 0.0865248800066132, 0.10246041044044676, 0.1158841305481071, 0.08065938504071898, 0.10460407470690787, 0.12063089821747253, 0.1163228777478342, 0.09134214029083003, 0.1169913687634265, 0.1276932103580502, 0.14632640333971617, 0.07592993468368574, 0.10346466665218168, 0.12588851253593045, 0.1456772307680954, 0.09371468454616506, 0.12315933527315946, 0.1441784389855239, 0.14526453243091142, 0.10740115004178274, 0.13740503682632102, 0.15207491667574438, 0.12172876174458105, 0.1081770901677246, 0.08040056062592552, 0.011765445624264384, 0.11991534924016369, 0.10582164464180539, 0.08386969342412137, 0.03196404089175162, 0.1124300439289906, 0.10085910333794194, 0.08071997365771655, 0.030574691459114747, 0.06328189539668336, 0.11508640566430263, 0.01790736534543805, 0.0507204808475887, 0.07967227691131844, 0.10440078974587004, 0.0330717214736125, 0.06680825954696219, 0.08912872408737538, 0.036217904960124815, 0.0993939475980532, 0.015718689830985337, 0.020242061295244026, 0.05050908824495131, 0.08480577398664588, 0.005577472638393332, 0.036243782056532885, 0.060225348438531466, 0.0699421925057243, 0.05173138698076428, 0.02604985795352494, 0.01829995327635539, 0.05233938627919301, 0.03808479220130822, 0.022058609691523696, 0.026619089132516274, 0.1118828428350652, 0.09568069776364246, 0.07243902926333853, 0.020219501392170273, 0.10337408463840285, 0.08989540393102165, 0.06903656319506468, 0.034453457996929414, 0.06619457389590347, 0.09857380138616645, 0.016274945662070897, 0.05097759123799717, 0.07592638730905575, 0.03431864875935569, 0.07838684231236367, 0.018183435387213093, 0.016583037481638495, 0.04400537915977782, 0.05268414721179819, 0.05082472118450106, 0.02064546693559786, 0.00978646663491599, 0.08817446767623122, 0.0709828655248912, 0.048856935504565775, 0.03473394991096607, 0.06060938401437219, 0.029553880258058857]

                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1
                        }
                    }
                    
                    if currentAlphabet == "Please" {
                        guard
                            let thumbTipLocationPlease = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCPlease = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPPlease = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPPlease = firstPose.keypoints[.thumbIP]?.location,
                            
                            let indexMCPPlease = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPPlease = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPPlease = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipPlease = firstPose.keypoints[.indexTip]?.location,
                            
                            let middleMCPPlease = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPPlease = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPPlease = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipPlease = firstPose.keypoints[.middleTip]?.location,
                            
                            let ringMCPPlease = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPPlease = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPPlease = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipPlease = firstPose.keypoints[.ringTip]?.location,
                            
                            let littleMCPPlease = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPPlease = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPPlease = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipPlease = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }

                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationPlease, thumbCMCPlease, thumbMPPlease, thumbIPPlease, indexMCPPlease, indexPIPPlease, indexDIPPlease, indexTipPlease, middleMCPPlease, middlePIPPlease, middleDIPPlease, middleTipPlease, ringMCPPlease, ringPIPPlease, ringDIPPlease, ringTipPlease, littleMCPPlease, littlePIPPlease, littleDIPPlease, littleTipPlease]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.16152835543105207, 0.11663291737412812, 0.051640228746214614, 0.04838627916278134, 0.04068114042702216, 0.07931048565712695, 0.10302258748819278, 0.06412215954495615, 0.07779066246136794, 0.10323181717547555, 0.11262217569054403, 0.08892725332304956, 0.09659450978969525, 0.11374136815148501, 0.11924549683632994, 0.11435440936832511, 0.11547044785925825, 0.12430605599839373, 0.1258725125483486, 0.051778814643098685, 0.11057302450157874, 0.12157739605765948, 0.1923913007142269, 0.23536931021596635, 0.25950629481961307, 0.13584898658219177, 0.22161578033626714, 0.2536803246071419, 0.26467554151701256, 0.14993819674197936, 0.22507229698574435, 0.25293431462580146, 0.2619912344287797, 0.16060603806795684, 0.21625923768989633, 0.2433317286564973, 0.2536038637167612, 0.06512551273283207, 0.08538178396784728, 0.1519571134297304, 0.19426853173885594, 0.21841523457544285, 0.10810624359316194, 0.1849222892272138, 0.21533430789743718, 0.22579567291300393, 0.1299893653280043, 0.1934419890256836, 0.21881599587707304, 0.22681122255025396, 0.14780550335122228, 0.19257852766932979, 0.21554288876645308, 0.22340125484246381, 0.03177805337510361, 0.08750832957523233, 0.12935157442446496, 0.15344260343213667, 0.061552588794022686, 0.12202438326433594, 0.15123521968894274, 0.16142206607375736, 0.0897512908447467, 0.134136720582924, 0.15705091425849624, 0.16425937119087317, 0.11394991744464142, 0.14105345757142287, 0.1589444087258446, 0.16449197306054422, 0.0711418425484467, 0.11406376535596625, 0.13810643154733274, 0.02983082507759578, 0.10063676908266447, 0.13224793885657152, 0.143162962563837, 0.05827291638577803, 0.10809121831754787, 0.13367205400381227, 0.14199454501058528, 0.08303253805646686, 0.11072039888129141, 0.13096899980121895, 0.13815118375280927, 0.04297993976918386, 0.06712505840133318, 0.06932958432915763, 0.037182333965608196, 0.0637772898901339, 0.07392398122411496, 0.08312144435724948, 0.058451794264373136, 0.07310218847007274, 0.07862271986603188, 0.1046805081605696, 0.08457821071905379, 0.08677362747103169, 0.08638032687905466, 0.02420097233589808, 0.10910392255125007, 0.02929255216350314, 0.02710103502927505, 0.03418679890171073, 0.11662718747444026, 0.05501213364051809, 0.04903380896422147, 0.048820211421760476, 0.13356014318602435, 0.0921730679168226, 0.07855533335206248, 0.07028184247639027, 0.13180586230563587, 0.04564574746100853, 0.02002072456207816, 0.017405440225693455, 0.13685045405296214, 0.06491945252091325, 0.04671895105818038, 0.04119559170044209, 0.1515394656439734, 0.10258954337110918, 0.08190829398266808, 0.06971253659658116, 0.08901424622948696, 0.12192348313932683, 0.13326789028281813, 0.02866315679954898, 0.08926385110060704, 0.11766264667032826, 0.12717429600778354, 0.05401990843750854, 0.08450011941481544, 0.10839747732445976, 0.11786951891729705, 0.032923644410697485, 0.044287305029866816, 0.09141701909137655, 0.02745549426802854, 0.03595370611612802, 0.042251954511520896, 0.10604651338674094, 0.0632920526693528, 0.054299045589837565, 0.05057253099256007, 0.011374643634521469, 0.12337172827136553, 0.04649610745835171, 0.026877720471895253, 0.022996475340420222, 0.13586794887002862, 0.08361068725093479, 0.06189536211504079, 0.0498693736023669, 0.13461709708844963, 0.05641302472651627, 0.032540089261533574, 0.025004227001083387, 0.14666809224337346, 0.09267855980981678, 0.06856978194376563, 0.05496327997324138, 0.08286245355232462, 0.11289419853250608, 0.12334391315407997, 0.025778996608502445, 0.06645542524104103, 0.09524246559992129, 0.10755511667440125, 0.030072064686960675, 0.040678097997240266, 0.09132347398002363, 0.037851587652497236, 0.02834847840493665, 0.030355814847193147, 0.010809052485395154, 0.12084710233541225, 0.06206120323190906, 0.03603703300998551, 0.02300241040576311, 0.13163817108936038, 0.07259124346070203, 0.045156298686785064, 0.03047750690980967, 0.06446897120322116, 0.09621689592341384, 0.11068322548078321, 0.03199538020050678, 0.047246490119636324, 0.015984961424508698]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
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
            //if currentCumulativeCount - lastCumulativeCount <= 0.001 {
                // Reset the UI counter to 0 if the cumulative count isn't increasing.
                //uiCount = 0.0
            //}

            // Add the incremental count to the UI counter.
            //uiCount += currentCumulativeCount - lastCumulativeCount

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
