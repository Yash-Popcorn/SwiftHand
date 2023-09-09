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
    var currentAlphabet = "W"
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
                    if currentAlphabet == "C" {
                        guard
                            let thumbTipLocationC = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCC = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPC = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPC = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPC = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPC = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPC = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipC = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPC = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPC = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPC = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipC = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPC = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPC = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPC = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipC = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPC = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPC = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPC = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipC = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationC, thumbCMCC, thumbMPC, thumbIPC, indexMCPC, indexPIPC, indexDIPC, indexTipC, middleMCPC, middlePIPC, middleDIPC, middleTipC, ringMCPC, ringPIPC, ringDIPC, ringTipC, littleMCPC, littlePIPC, littleDIPC, littleTipC]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.4497942219418446, 0.3081736278358197, 0.16348798134171152, 0.3061889256371902, 0.277487222259097, 0.26037029903007, 0.25343171290028066, 0.3428602971894933, 0.31177341984018997, 0.2776080866744615, 0.26934028534019505, 0.397683810680491, 0.3510160989305484, 0.3050855466467381, 0.2903694040889991, 0.43941710578320203, 0.3509369220682138, 0.31499364505919625, 0.29265217263392806, 0.14187807419643197, 0.28727256254566513, 0.3163384113598663, 0.43251314107871186, 0.4913047661697515, 0.5673452140292872, 0.31619377324450826, 0.44382845346182864, 0.5175929671082243, 0.5932473431993669, 0.3037472786798413, 0.41064913358461214, 0.4944439139597884, 0.5781362957634474, 0.27684163250635513, 0.3772363526566272, 0.44187103117546744, 0.5080110621713829, 0.14539452074990042, 0.23982260015818968, 0.33530799795867633, 0.3830681776325805, 0.4478618866950737, 0.25555487073079985, 0.35502948338507206, 0.40999616021260643, 0.47320798903713585, 0.27043501026979455, 0.33915280317869645, 0.39675134986842503, 0.4646890982481987, 0.2709134937847636, 0.3109813705704778, 0.354287710330967, 0.40528808508907105, 0.23581849889977224, 0.27863488700978234, 0.3024025524182782, 0.34346260128251943, 0.2673527415098001, 0.3082745183524273, 0.32787636794501285, 0.3666420470864183, 0.30858851627443695, 0.3190108183349085, 0.3314670299464931, 0.3692971046057229, 0.33430721676129915, 0.3027656538545773, 0.3094253541105148, 0.3313582897249006, 0.12298525677111904, 0.19090821375409306, 0.2810721025106897, 0.03667673427314142, 0.12817118715801215, 0.21433156155926028, 0.3062127522239075, 0.09354895727657077, 0.09948558304463664, 0.1821411595819485, 0.2797943209085558, 0.14361123593310918, 0.07212265918388812, 0.12590723651310873, 0.19953950251799196, 0.07061141805555414, 0.16449553260338481, 0.14295562076544635, 0.034309058287463015, 0.09186976994048486, 0.18824683759506095, 0.1956715976630447, 0.0857467700607014, 0.0622092899561507, 0.1579110277241632, 0.25180609328201164, 0.10486964193102717, 0.03754797936322908, 0.07673979082957308, 0.0942878066111618, 0.21325884180172835, 0.08798762797214081, 0.026930042418451847, 0.11766079965331266, 0.2662508851136304, 0.14978206100365646, 0.04817824244744881, 0.08908275063805571, 0.32241050054552717, 0.17385251192605417, 0.09252858912741757, 0.03238151864459585, 0.30599648835143595, 0.18100819659423248, 0.08066349377246955, 0.025970001669227225, 0.3600738159695584, 0.24313151694585694, 0.12984769810590616, 0.04057174643048116, 0.4160918034344539, 0.2681213575155864, 0.18549523267968462, 0.10484054315395798, 0.1396244728265406, 0.23459181215951436, 0.3304577869817607, 0.05832892617271915, 0.09499803412749243, 0.1969897871958696, 0.3007575519905646, 0.11161296911397514, 0.061059132682186525, 0.13640736586527993, 0.21712728698343628, 0.10203461694361039, 0.20268379073750878, 0.1861335628946329, 0.06212727480112194, 0.05817502099469327, 0.1669711863474397, 0.242267942845215, 0.08973639821490463, 0.004544173498169678, 0.08075994462362895, 0.10086850949505241, 0.2857316756275731, 0.16393735513323843, 0.049265762423449586, 0.06619530941570462, 0.3420264206466312, 0.19103912318261437, 0.10640723696577775, 0.024483346416862957, 0.3839090375464689, 0.26472079899398054, 0.14906716439291307, 0.04452854579327962, 0.4400514459345988, 0.2908982204923631, 0.20710533637460402, 0.12406959932470622, 0.13049025618676593, 0.24429964044163993, 0.3517776297796429, 0.056296837943376574, 0.09720876423050574, 0.1822843399742047, 0.26635285918913254, 0.11790538294513679, 0.22813607781862336, 0.18541681012594668, 0.0347248273124287, 0.05765691137471363, 0.14186508267898418, 0.11045492238288881, 0.3004050331907706, 0.14766943664772741, 0.062040198508440836, 0.025062720074282948, 0.40807395788634465, 0.25653601095430506, 0.1711992993189234, 0.08630759567138856, 0.1529522258517829, 0.23836694560520286, 0.32260303914825195, 0.0856815951923572, 0.17045961939490217, 0.08493774975416912]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "D" {
                        guard
                            let thumbTipLocationD = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCD = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPD = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPD = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPD = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPD = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPD = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipD = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPD = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPD = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPD = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipD = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPD = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPD = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPD = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipD = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPD = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPD = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPD = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipD = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationD, thumbCMCD, thumbMPD, thumbIPD, indexMCPD, indexPIPD, indexDIPD, indexTipD, middleMCPD, middlePIPD, middleDIPD, middleTipD, ringMCPD, ringPIPD, ringDIPD, ringTipD, littleMCPD, littlePIPD, littleDIPD, littleTipD]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.18319268041766207, 0.09206516416958968, 0.09290278134952096, 0.20561140852478874, 0.26774375681555485, 0.3286214194463164, 0.38913023423117954, 0.3687270386567475, 0.29475935589650665, 0.14923952507411187, 0.07451325418555534, 0.47591934254408486, 0.4005642480690811, 0.2534047936687314, 0.16790036414835763, 0.565336701214629, 0.47418818295784526, 0.35427120991264893, 0.29298892451336145, 0.12430414571881707, 0.21023011126768382, 0.27864029305347227, 0.382395370978932, 0.4541547853630712, 0.5140469684598539, 0.36798864645146095, 0.31549972472052573, 0.19714438369444634, 0.12030864582871173, 0.42398822942860204, 0.3583396285140353, 0.20255495681787375, 0.07269102537791794, 0.46918549345522, 0.39046452556681444, 0.2540293404380242, 0.15189292315103983, 0.08596736761183918, 0.2734297717007683, 0.3520861497879403, 0.4165402483740515, 0.47744261882908645, 0.4139632362177407, 0.34620217844371987, 0.20027069093445163, 0.08892664704309373, 0.5010533611790174, 0.4284328246321965, 0.27008641315862814, 0.14782676917178372, 0.5696530735168344, 0.48369313517961704, 0.352213509449158, 0.2661157976654241, 0.2982941712487754, 0.3524395216227038, 0.40754436844304215, 0.46656053631491057, 0.4602035573762831, 0.3870111932211479, 0.2402614570729467, 0.14447602200236026, 0.562040255059981, 0.48734473469657985, 0.33427918005527496, 0.2255362137436654, 0.6423297564132492, 0.5534957051834529, 0.42660513564035746, 0.3483288905273638, 0.11337821302242528, 0.18600301742775666, 0.24206302097798316, 0.18021288838730698, 0.10409428932881634, 0.0817298457137485, 0.1878692535439516, 0.31186313368939433, 0.23913699895044702, 0.15988175578890376, 0.21117778316782232, 0.43279990072939084, 0.3398299101815313, 0.26557037773895287, 0.2784940194587844, 0.07307817409021017, 0.1317113239570763, 0.23427313569062855, 0.1750319589709939, 0.1878641294390767, 0.2768840829954122, 0.3763929635608321, 0.3128322331882905, 0.27012293068094995, 0.319279537855454, 0.5115566894991131, 0.4223651279294118, 0.3698750704877713, 0.39171906909054577, 0.061024695579789866, 0.28120121053443436, 0.23396494937464263, 0.26073805117566495, 0.34569415949218574, 0.4215917032776503, 0.36480843244872163, 0.34020975728438924, 0.3920343448742426, 0.5618393209050886, 0.4761203678923902, 0.43598643380514657, 0.46372565436463825, 0.3112075029561516, 0.2755259562857869, 0.3192989838754594, 0.4065770617526029, 0.44659777312467425, 0.3969275577946103, 0.39102531263881457, 0.45077321635430717, 0.5897499139388723, 0.5082201607614929, 0.48117619105892645, 0.5170961267240567, 0.0766020194856794, 0.21994259201272207, 0.3257126355452329, 0.14214882466218987, 0.08598988414564449, 0.16799757729891615, 0.2965123313899704, 0.2806465287690634, 0.19701947103962975, 0.20052188766180043, 0.2839045044627387, 0.1477032142804534, 0.25728893834099203, 0.20985222589486635, 0.1402304933321599, 0.1319983696773404, 0.2428087011178099, 0.3382834227337259, 0.24776404334220511, 0.20626787227450052, 0.2606737128113944, 0.11175402053575237, 0.32955040280861425, 0.2539093045605883, 0.12342022110906473, 0.13147516830664827, 0.43045991756262514, 0.3372111479356516, 0.2345256719831865, 0.2169803354140788, 0.41887621502996175, 0.34484717990089947, 0.18989690095578643, 0.0934803870714998, 0.4985053504926285, 0.4091321181569142, 0.28420781415552193, 0.21848245439986141, 0.07564317358938831, 0.23101503581172642, 0.3617319429930624, 0.1443491837519014, 0.0841503259223142, 0.18386112067404428, 0.296425101936642, 0.15959189595088186, 0.29275745729555364, 0.19873105824629092, 0.11150309469423439, 0.1399635241399528, 0.2439016669307161, 0.13394572187261466, 0.31229667771735514, 0.2207841742911868, 0.1114426177842462, 0.12943850317569902, 0.42206806582198164, 0.33739552136683876, 0.20450023911755136, 0.12555932611209952, 0.0936547375408085, 0.21761260137309157, 0.3201168215370628, 0.13664667115285228, 0.2479136578163861, 0.11357698530047047]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.065)) {
                            uiCount += 1
                        }
                        
                    }
                    if currentAlphabet == "E" {
                        guard
                            let thumbTipLocationE = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCE = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPE = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPE = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPE = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPE = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPE = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipE = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPE = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPE = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPE = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipE = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPE = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPE = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPE = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipE = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPE = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPE = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPE = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipE = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationE, thumbCMCE, thumbMPE, thumbIPE, indexMCPE, indexPIPE, indexDIPE, indexTipE, middleMCPE, middlePIPE, middleDIPE, middleTipE, ringMCPE, ringPIPE, ringDIPE, ringTipE, littleMCPE, littlePIPE, littleDIPE, littleTipE]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.19068248000829352, 0.1207284367477918, 0.10105655277307893, 0.04344733416949941, 0.08338477062921953, 0.07165391445308061, 0.07225893642427152, 0.1316002874021136, 0.1573085641325819, 0.06970998516003402, 0.04691687882432701, 0.23592309447397594, 0.23683016798969606, 0.1773700349610365, 0.154775560485222, 0.37133273745930684, 0.3312631942899394, 0.26885278755043546, 0.2425070743241571, 0.13918915184333017, 0.20034519621260866, 0.23196875289181837, 0.2689003199293757, 0.2551881121314271, 0.21468608873498718, 0.240930961595169, 0.2862348568996485, 0.2314973135525482, 0.15729160584375323, 0.284116837451335, 0.3204966852977905, 0.25711129213153205, 0.17526719122589154, 0.3706085705450233, 0.3655871718106748, 0.29927991178748387, 0.24331574762387503, 0.06692597145337616, 0.16074723387990258, 0.2003314087870521, 0.15373760533427935, 0.0960306932659217, 0.23840629382747267, 0.2725702257807307, 0.18881575653457827, 0.1265570830415504, 0.32631040469221323, 0.3412995635483279, 0.2765194176408564, 0.22187142821313846, 0.44662539199542683, 0.42055121489193925, 0.35357871471087204, 0.3115301226662652, 0.12825635239963704, 0.16295705046217504, 0.1013067239511029, 0.040339387516544166, 0.23247136477024669, 0.2572928474245306, 0.16870747832590474, 0.13087727031100715, 0.33393783009340733, 0.33778429742625843, 0.2772278628892622, 0.24131911814396848, 0.46505696461020524, 0.42958014494279956, 0.36530484497904714, 0.3322071834239626, 0.040176513840216775, 0.055135056826786245, 0.09094447261470569, 0.1198327687133, 0.13332559952872694, 0.04752614675840994, 0.07846912928686563, 0.23017800049938816, 0.22081318226714974, 0.1685953813380165, 0.1678736631606628, 0.3701021560514166, 0.3231875450394431, 0.2652733379844997, 0.24845250785789696, 0.07164173687789803, 0.12352679047697436, 0.11640666647760821, 0.11529008959405895, 0.051514719264149286, 0.11235557755961878, 0.2260236246235174, 0.2069579488457399, 0.1641716406475978, 0.1831326706918487, 0.36742141141881496, 0.3147554641093087, 0.2621972724022542, 0.25456156459961393, 0.06130278403894705, 0.17456447116213145, 0.18367480608965361, 0.10206248933903271, 0.1182000615448613, 0.2851610719704802, 0.2735464074524852, 0.22342337514057534, 0.2198811854130749, 0.42523326045139753, 0.3776866995976888, 0.32036377841990016, 0.30284665258168725, 0.2023860577322372, 0.22295532686320865, 0.13457541578609708, 0.11192751200462556, 0.308141105477548, 0.30695121511907836, 0.24913311141178401, 0.22383902281933984, 0.4432940265354515, 0.40339404350338015, 0.34109698415746054, 0.3132311337950303, 0.04616945244653708, 0.0725019833552701, 0.11196946632441455, 0.11084834524621613, 0.10533605275979412, 0.04888778252966187, 0.08910861454000957, 0.25183828953071813, 0.20338642400956472, 0.14657200907992016, 0.14038934422750343, 0.0886413334221225, 0.14870404896444817, 0.12075456494867705, 0.09202746545636324, 0.06618089802196768, 0.1329118269699895, 0.25965578543944046, 0.20193707195636373, 0.15667881625241042, 0.16713884140036298, 0.07572820048832503, 0.1831881619831841, 0.17368005885387972, 0.12136786480542437, 0.13162433973527599, 0.323703273320795, 0.27573746672206173, 0.2186046732976121, 0.20546975746921747, 0.20436517159590362, 0.21498591309128556, 0.15089237903109312, 0.11203208640192946, 0.3342325164006452, 0.2998768466348659, 0.2347665375917043, 0.20214017545090457, 0.056565488153242145, 0.06205828411153401, 0.11104589287359488, 0.14140076183030148, 0.0956440473927644, 0.036359429592232324, 0.06555721424157852, 0.06594839923090205, 0.14562302140313146, 0.17457942480644303, 0.11157946512232002, 0.08217844662936903, 0.12182048929377444, 0.08502473062291152, 0.203328692122305, 0.1549150380491553, 0.09805301359992855, 0.10095903535108161, 0.22540892897845016, 0.20084297334110648, 0.1331384508816211, 0.09104961715649716, 0.0703199781553932, 0.1052889042890442, 0.1351123439514863, 0.06776238392051633, 0.12284772594748548, 0.06018582961185522]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.065)) {
                            uiCount += 1
                        }
                        
                        
                    }
                    if currentAlphabet == "F" {
                        guard
                            let thumbTipLocationF = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCF = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPF = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPF = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPF = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPF = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPF = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipF = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPF = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPF = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPF = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipF = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPF = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPF = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPF = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipF = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPF = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPF = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPF = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipF = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationF, thumbCMCF, thumbMPF, thumbIPF, indexMCPF, indexPIPF, indexDIPF, indexTipF, middleMCPF, middlePIPF, middleDIPF, middleTipF, ringMCPF, ringPIPF, ringDIPF, ringTipF, littleMCPF, littlePIPF, littleDIPF, littleTipF]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.38145903259291375, 0.2279083868411884, 0.1127284112210908, 0.28315375351364747, 0.20903527838273842, 0.10543775034351033, 0.02501293515958707, 0.37789943930033226, 0.3459066186738597, 0.3222244698785142, 0.31217794519522984, 0.4822638054166836, 0.44543029971230663, 0.4296825147840901, 0.40823839038674925, 0.6158144425093779, 0.599104844748401, 0.5789380529814792, 0.552110510484679, 0.15473565267124187, 0.2716066508657661, 0.22774251942590584, 0.3054128841284799, 0.3574425667175134, 0.3678615852492497, 0.25932433568338553, 0.34518454653290687, 0.40877554362632823, 0.4652907636780239, 0.30854135238889385, 0.3607118091956128, 0.40938840533183046, 0.44991883920159637, 0.39028903388878833, 0.4239412594076716, 0.45518924898185714, 0.4816719464749288, 0.11692263525189578, 0.18289355991643827, 0.20826735625482745, 0.2208109095661072, 0.2161684272704368, 0.26478287536028927, 0.305041642951771, 0.3401542973041331, 0.3778590630171999, 0.3535030132362343, 0.36483117654383984, 0.38817734239899426, 0.40552949079691886, 0.4692767241935894, 0.47929592884878297, 0.4873231779878285, 0.49045085608429406, 0.22275094278093238, 0.18892153223354224, 0.14017286347255234, 0.10523536677227437, 0.3189285860010228, 0.31981824156182204, 0.3250033378342583, 0.3401740635606434, 0.4199442454879913, 0.40477847999918254, 0.40754120943177496, 0.4047493503981307, 0.5476189599687874, 0.5435064618475458, 0.5365763462384785, 0.5237594977579426, 0.10210207869798721, 0.202388348350464, 0.25963967059897636, 0.0968398559788847, 0.1254253268379566, 0.18104514341821076, 0.239791897009755, 0.20025920501619604, 0.18564645727945, 0.20555034373456943, 0.22982620000552337, 0.33276420419064234, 0.32153362666471075, 0.31485972784304983, 0.3095735397903308, 0.11148955305900132, 0.1840484835306363, 0.18060579381335082, 0.13779101558974274, 0.13784184108802966, 0.16973855936219057, 0.28291406762333493, 0.23663698526099772, 0.22388247090059823, 0.21582872546382945, 0.41806858509789036, 0.39340992468318875, 0.36998405223529396, 0.3447689278385755, 0.08132504728428246, 0.2902641684498896, 0.24407443515984026, 0.21683914884034355, 0.21185036620934414, 0.3936291992843681, 0.3466590946006103, 0.3258474699920795, 0.30280402907876086, 0.5286901298745994, 0.5048244456474572, 0.4792503265157133, 0.4487250352381429, 0.35386496338417694, 0.3208972273881607, 0.2981312384579323, 0.29036136561892684, 0.4582380171685755, 0.4204978559383055, 0.4047625948967379, 0.3840037995451764, 0.59206430154558, 0.5745496449786405, 0.5539806489868784, 0.52714104306614, 0.10842409281166311, 0.19194810654218855, 0.26389608044624197, 0.10437365753635001, 0.1040841072419341, 0.1514420094364393, 0.2018634894175122, 0.23875034314213073, 0.22476188639005754, 0.22288670919648748, 0.2296080369288668, 0.08501266888269816, 0.15823877210073697, 0.18055412707967217, 0.10616261239847771, 0.08772401078264473, 0.10526349018068132, 0.3093298727427215, 0.26960526829762854, 0.23586017707343435, 0.20699592534041067, 0.07339908746030668, 0.263044605132593, 0.17762356609661867, 0.12611907061342706, 0.08628846740590955, 0.3870550273748229, 0.3390090617703636, 0.2926118941093103, 0.24537580439206413, 0.33611089869229366, 0.24817304731207024, 0.18911974624041167, 0.13065454923661096, 0.458107091071141, 0.40648175759276106, 0.35449995411653795, 0.299093551043737, 0.09815176924173868, 0.1705384211975309, 0.2386224136531897, 0.13515524525977318, 0.12584368663285384, 0.1467701198768343, 0.18436586044335906, 0.07239132317219002, 0.14103057931976556, 0.20993603802539787, 0.1637669586614964, 0.13366515982787563, 0.1260716741927779, 0.06977487483845249, 0.27510282067299163, 0.21802892861210388, 0.16668350080054634, 0.1230866451472296, 0.34436068440511985, 0.28453794886035694, 0.22655506802616868, 0.16845037922837158, 0.07774788814927423, 0.15193765143739657, 0.2239347565820586, 0.07480696505182495, 0.14831045282043723, 0.07439193341127369]
                        
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "G" {
                        guard
                            let thumbTipLocationG = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCG = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPG = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPG = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPG = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPG = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPG = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipG = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPG = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPG = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPG = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipG = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPG = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPG = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPG = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipG = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPG = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPG = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPG = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipG = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationG, thumbCMCG, thumbMPG, thumbIPG, indexMCPG, indexPIPG, indexDIPG, indexTipG, middleMCPG, middlePIPG, middleDIPG, middleTipG, ringMCPG, ringPIPG, ringDIPG, ringTipG, littleMCPG, littlePIPG, littleDIPG, littleTipG]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.5019768251903893, 0.3270031109437454, 0.13224940627868825, 0.45037938430350544, 0.19458478500008114, 0.043935618663301555, 0.043536336152104456, 0.49229051781449423, 0.1857873506816688, 0.2620047205471675, 0.32770108204514947, 0.5282285852009387, 0.2720422200355206, 0.33589774798005506, 0.40026711769542944, 0.5466948305194268, 0.33827607556917416, 0.3912336084865734, 0.4558016995304154, 0.17853111265480553, 0.3701218147213413, 0.12392487316940456, 0.3266011065423823, 0.47405326648220925, 0.5454829097064183, 0.04930397814725013, 0.32402569378775387, 0.2498694758960345, 0.17747673418563342, 0.03243048241521847, 0.27470749196364175, 0.21487652720450717, 0.1441463199796272, 0.1084656825038792, 0.2704945966723298, 0.23018721044606613, 0.17480592415039797, 0.1948038125448615, 0.13611688722161852, 0.14851759578986018, 0.2967127440695993, 0.3702327076705901, 0.16533351160511628, 0.16158782884722486, 0.1043591398636177, 0.05568918693999792, 0.20776716331172684, 0.15671787674775467, 0.13883063024555128, 0.13536303812400727, 0.24868120621210432, 0.2020480227245151, 0.20359869333848157, 0.21265192526633833, 0.32085581638250205, 0.07755632472904751, 0.10569239113102416, 0.17560466254477428, 0.36012785121749263, 0.07101580762488877, 0.1383501637646555, 0.19789540536424882, 0.39691832687403616, 0.16594740907831557, 0.2201869593124341, 0.2764000673079075, 0.4200585296019584, 0.24046536946304647, 0.2846848914169567, 0.3394037907681615, 0.2581436402321675, 0.41513860738916675, 0.49240673960700204, 0.07816537919290793, 0.29690673353017755, 0.23864467148357243, 0.1733803651149743, 0.154515132579089, 0.2852188225066904, 0.24722889810794704, 0.20233112208153414, 0.23103634621820138, 0.31260454246892666, 0.2926944752918046, 0.2643127885033202, 0.15725747020556533, 0.23538191115031035, 0.3081458301479292, 0.11044121775522697, 0.13941530910180733, 0.17246293720466252, 0.3562398554242381, 0.18832499247093618, 0.22305041444796117, 0.2608923671478494, 0.39329450213107986, 0.2622728010279921, 0.29398528737809804, 0.3331874996837781, 0.07901618904762517, 0.46113296781601554, 0.16957666293429202, 0.2427424380782773, 0.30350624009417243, 0.5015503112361219, 0.26185473313435725, 0.3217947769079705, 0.38137586704802107, 0.5256910524635141, 0.3325982192846936, 0.3821465718933023, 0.4418723659945939, 0.5354565685619113, 0.22866384108066856, 0.3051021924769255, 0.371200402069352, 0.5717648500341148, 0.31301814754194796, 0.37776867021905525, 0.4430999444868454, 0.5897778678674543, 0.3772494780186539, 0.43134314933213347, 0.4973731871369356, 0.3221787521943643, 0.2525313607412282, 0.1797359247212851, 0.07728175418013317, 0.2866895001987806, 0.2338496088131474, 0.17082614396559298, 0.15765482052621416, 0.294742690214687, 0.2614797287827117, 0.21522567945024343, 0.07673075896512724, 0.1466334556306441, 0.3478563966881056, 0.09498454305374364, 0.15221951824904525, 0.21448266492874213, 0.3611741118495309, 0.16949332296345565, 0.21432523094701764, 0.27233018393182784, 0.07311027587201481, 0.2724092927007254, 0.05877052863406901, 0.08493641708492285, 0.1387550985985931, 0.2846929757046036, 0.12551212885271942, 0.15482101918899985, 0.20170667550536306, 0.20142974602209796, 0.11197285933385101, 0.08340389288400725, 0.08967764280471806, 0.22355177431908133, 0.14762683417885047, 0.148354016155289, 0.1654008179280416, 0.29215704438934886, 0.22909893529729053, 0.15522639852370493, 0.0836333394994674, 0.28004028929091807, 0.23472718116455155, 0.17114031451427925, 0.06786420415830775, 0.14145317869198584, 0.2874873231709835, 0.07543410957797589, 0.1202920417925265, 0.18478809930352777, 0.07503611238029, 0.21970876839653644, 0.06570878003331058, 0.07168812415706459, 0.12017810281412888, 0.14758603404457327, 0.12634947576683808, 0.09166320491354368, 0.07729421545267913, 0.25413518181812234, 0.19929853622085741, 0.12273223573934608, 0.058651556052584854, 0.13597411439443632, 0.0783319322734916]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                            
                        }
                    }
                    if currentAlphabet == "H" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        // Calculate distances and store in an array
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.3296134591701803, 0.2094517970823037, 0.0978488949957563, 0.21738646359011907, 0.08796438998928004, 0.1569908060787094, 0.23306095865418272, 0.19190369460577825, 0.05071236726329158, 0.17648995499538137, 0.26272584483127215, 0.17064039583301724, 0.05187516355443339, 0.07907313345721784, 0.10454234121031736, 0.17385546286273665, 0.09533725609448526, 0.10434318810175115, 0.12717993027786842, 0.12302243297681965, 0.23256738643064548, 0.14551663301754914, 0.3357318426812758, 0.4641181313732832, 0.5496442114023102, 0.1432458116156578, 0.3593235296945211, 0.5012136969239841, 0.5877465524121762, 0.16166707177613224, 0.3079183550185444, 0.29885406263671854, 0.2640776417549432, 0.19296768046353577, 0.29879403003062616, 0.28852993306351465, 0.255279222856743, 0.11160757542367769, 0.0532437588059966, 0.213547318869152, 0.34120312709626116, 0.42662853375270077, 0.020890622081343648, 0.23655423473499732, 0.37859020170814145, 0.4650073251184168, 0.05743734394929058, 0.1949933892488196, 0.1919395716842585, 0.16224191204595237, 0.11494678908780945, 0.19631078221487788, 0.18852269521515905, 0.16150299929115094, 0.12454285846102284, 0.11993977948795581, 0.23758925171279735, 0.3207553419989187, 0.09429814526728712, 0.12856260539199985, 0.26933445181384447, 0.35601599048482613, 0.07867625430733852, 0.09134090426370106, 0.09860749328686429, 0.08550648463977768, 0.10719860248870482, 0.10977582996162989, 0.10777548957116634, 0.10010314711897135, 0.199279839960021, 0.3296322235302624, 0.4161810929035586, 0.04651680942898132, 0.23361922665959656, 0.37411440271416535, 0.45896117355140015, 0.10144103309267294, 0.21548484796698808, 0.21875891688006247, 0.19489751703182356, 0.16239779409700728, 0.22649139465837742, 0.2208698659934197, 0.19921819723303458, 0.1303557091291491, 0.2169179434819858, 0.19284408276722134, 0.055595628290370694, 0.17845431841447792, 0.2610449646201553, 0.19666692300228902, 0.134626983756561, 0.16017114646266278, 0.17465295509950124, 0.22440278064136934, 0.17683784446648132, 0.18324091745022889, 0.1964604609090207, 0.08657471184038878, 0.32087368205243977, 0.11076476882674068, 0.06307529895654972, 0.13343821211491647, 0.31619919366913557, 0.20557440644125013, 0.23180394684896496, 0.26116669901586714, 0.3295995922985296, 0.24644290626299695, 0.25726652804123745, 0.2836237401153969, 0.40648687750940027, 0.19225834329483618, 0.06382440479791156, 0.0549134638740714, 0.39886030925471394, 0.276704106879769, 0.3009467865088436, 0.3338132567966078, 0.4068260336953672, 0.31373411782670824, 0.3255135582902805, 0.3554628584924465, 0.21707190834798598, 0.3591659155838229, 0.4454424465229442, 0.054958616488259025, 0.18094748422399926, 0.1802809862856441, 0.1530675231438437, 0.11588433457289352, 0.18615226962786907, 0.17935648749595157, 0.15511526446359744, 0.14209439509475985, 0.22845495889051956, 0.2066202373221333, 0.10254036082339307, 0.12974389893154487, 0.15424450577258447, 0.21920785785161714, 0.14590020005356993, 0.15505408900897258, 0.17696197863321464, 0.08669068024522446, 0.3459065997186038, 0.2166272176734046, 0.23983520381119847, 0.2738076264572132, 0.348791485432249, 0.25192785037338256, 0.26391160171646305, 0.29494589837990787, 0.4325346069021871, 0.30066071987961246, 0.3225162783781539, 0.3575639830789071, 0.433826289701203, 0.33342542213296705, 0.34567174954434876, 0.37804014898232663, 0.14630112676124424, 0.13899455728723828, 0.10675542086445787, 0.061156066940692776, 0.14142265922281608, 0.1327562421761127, 0.10428650626072226, 0.027203757347414925, 0.05719706181378046, 0.13375164858704833, 0.04352924087418467, 0.05260402178321033, 0.07881593806355329, 0.03693933077953588, 0.11593076409358492, 0.016689601963697346, 0.02556489835421885, 0.05558707379569659, 0.07899373488981298, 0.0348668960311831, 0.026325018108089116, 0.022719521931287925, 0.1111029922118808, 0.09947936218704409, 0.06431835206475874, 0.012418417729322678, 0.04752267655653038, 0.03545684902387898]
                        
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "I" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.13657923265036523, 0.12345446760894746, 0.07438153717606308, 0.10795096937955687, 0.07600034567302512, 0.031840553543651715, 0.013685966683748049, 0.010736772603500025, 0.07229539076468182, 0.07314967154959535, 0.06278988882403003, 0.11223481235770211, 0.13664893626211305, 0.15129899130028066, 0.14844266550545399, 0.2189785532652785, 0.22304904654827565, 0.25183428362613103, 0.26602773811649943, 0.09973058560353307, 0.1215639002297355, 0.14830145889212928, 0.19173125877299332, 0.16611753867142084, 0.13255390862289348, 0.13434833878401395, 0.19992242951831102, 0.17952222628976672, 0.14983814591222433, 0.1891850897675376, 0.23049501708946513, 0.22853916551591083, 0.21077217587763394, 0.276785829623636, 0.31137585113885446, 0.35121417028072804, 0.3719058940890987, 0.05721826052915844, 0.05961087384281785, 0.13529324203914544, 0.1380811501026001, 0.11124399171161185, 0.12924251981967283, 0.19514863768218704, 0.19354498684878393, 0.17321955137617875, 0.22371218643616855, 0.2560814040695218, 0.2653256599677259, 0.25567298081039075, 0.3273289446523428, 0.3428871758641308, 0.3744040781827396, 0.3893691885000451, 0.03785831740991509, 0.079729928448076, 0.08257373139174123, 0.06084722095822838, 0.08269684326177151, 0.14263387061685345, 0.14747066666916828, 0.13310623917163544, 0.1841452733982383, 0.21098309641431726, 0.2244758919202459, 0.219087050364309, 0.29064292037166106, 0.29742949986370065, 0.32546229855157705, 0.3385022073862157, 0.0866742959633743, 0.10826037870101651, 0.09429412577733252, 0.11732157661327197, 0.17073273487069832, 0.18068360623157234, 0.16902567814691008, 0.21966827506763925, 0.2439101311846744, 0.2592313330498554, 0.25522382452718256, 0.3264282734120705, 0.3295194876435468, 0.35496968266598816, 0.3661812066209298, 0.05067417374168024, 0.06934994445778947, 0.08603474376698042, 0.10397955718727078, 0.128690231114888, 0.13207712943681663, 0.17448493245421084, 0.18537834224107547, 0.2073838949134615, 0.21130841754226082, 0.27716574161164825, 0.2649258191143637, 0.28317621012227817, 0.2906121422129191, 0.03367347469676762, 0.039429923642532325, 0.06261221686206159, 0.07977460462569116, 0.0814383280549056, 0.12471472042762555, 0.13990276201401808, 0.15957449407391772, 0.16164103261716542, 0.22911970509116783, 0.22329509973495323, 0.24686382985549607, 0.25797846751090286, 0.023366887388807732, 0.08391135224867952, 0.08680114991167256, 0.07577097053073206, 0.12568185496323986, 0.1502842031300925, 0.1649393260571158, 0.16172439241971143, 0.2324592002531772, 0.23660719947433273, 0.26495228986985525, 0.27872881228723484, 0.06913405685212005, 0.06509202804187697, 0.0524213918444587, 0.10241530469778298, 0.12851402044032673, 0.14202208370132882, 0.1383675675069698, 0.2092023673632632, 0.21520925412827563, 0.24523100824677338, 0.2602536586829604, 0.0379637404733751, 0.06298448292758972, 0.08098323767853961, 0.08188365325836458, 0.10609128438966452, 0.11513916440350794, 0.17538903463563094, 0.16168994737975523, 0.18426820984037026, 0.19598848347457337, 0.03088060365722508, 0.04633473071785949, 0.0635124534932818, 0.07999673839867118, 0.0827902366666927, 0.14936863300258515, 0.15011882882145555, 0.181138888005592, 0.19774349028578705, 0.0511700430621711, 0.08444241591596557, 0.09231471659098663, 0.08620246485193635, 0.15755045016834002, 0.17047116626461556, 0.20548735916443797, 0.2240262150941649, 0.04316669232419775, 0.04173804458869274, 0.03693186137050285, 0.10678707571209378, 0.12300425589759241, 0.16208211922136329, 0.1836431416841946, 0.029163416616925418, 0.05027369678413109, 0.09450536656198964, 0.08685026166846736, 0.12136349625632152, 0.14143726345567645, 0.02549359351524939, 0.06978299024537556, 0.08286905593119781, 0.12490527381231377, 0.14875539973493515, 0.07184659832498938, 0.10332612621279257, 0.14753392120171424, 0.172413391072906, 0.07045983119185976, 0.1153896121392088, 0.1436235668963647, 0.0468001732231379, 0.07445966180494104, 0.028251771336253662]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "J" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.31267847246477704, 0.21776079486609384, 0.10197672854615697, 0.2014732122954934, 0.030468513615732117, 0.06836509452377537, 0.07221073595957804, 0.15717732545872184, 0.11142878097258802, 0.12512336691669756, 0.12392117251792266, 0.16526495298867763, 0.17210593800454668, 0.1817335541548533, 0.17244084561162182, 0.2127246522524605, 0.2550240030167942, 0.32280663152208916, 0.3643414049005645, 0.10410554469994289, 0.21356770945782735, 0.13678400579561117, 0.327065661432269, 0.3251287029603546, 0.2643163940648337, 0.1557844414381936, 0.3649619293856787, 0.32993066301692164, 0.2611374867946523, 0.18770797302607772, 0.3752997809191134, 0.35114184986977337, 0.28915334918964847, 0.2811172720721972, 0.45269088593976436, 0.5532975328241618, 0.6141509769480104, 0.11587934985688261, 0.036219989767801615, 0.23661457255756554, 0.2432838856837869, 0.182675301937823, 0.0715796216304897, 0.2883218732596415, 0.262337868150257, 0.19770282807756662, 0.13715027403102223, 0.31374460586780084, 0.29697915388251866, 0.2412481986774161, 0.24893564083644554, 0.3986175955784613, 0.49281214235610626, 0.5484260850811394, 0.10104640834964043, 0.12273147366152028, 0.13718654036446398, 0.08344991933097183, 0.06285218267132786, 0.18532923090889525, 0.1718847923710517, 0.12402920799430202, 0.11047889469703855, 0.22604129868310732, 0.21958269902438857, 0.17982154359266567, 0.2063265961319128, 0.3141056966509805, 0.39860826343895056, 0.44846168857452084, 0.22371517693832996, 0.2363679238666266, 0.17814911227810284, 0.07774997768902435, 0.2834916556911658, 0.26309753768399197, 0.20297875422254338, 0.15243919546206575, 0.316236977727795, 0.30319216999603316, 0.25169988939702787, 0.2650085591717914, 0.403058805489844, 0.4933996723112331, 0.5461521922799905, 0.041500921755841004, 0.0696424362956879, 0.17153430303030676, 0.08122602028182592, 0.099606288567521, 0.11244793194736688, 0.16601307350676095, 0.1435496645384829, 0.15594598092734963, 0.15451994674478117, 0.19660111716939466, 0.22512628732680037, 0.2924830904847799, 0.3349053588174123, 0.061232296522153735, 0.17352759399331225, 0.0486504559828032, 0.05811184621274918, 0.08376301290067537, 0.1495076666325175, 0.1038763977140813, 0.11447362854027476, 0.11691761911799055, 0.15990572000730705, 0.18834649669400766, 0.2635159099945493, 0.3113792199499218, 0.11239319739374948, 0.10584350727083693, 0.08850548676336567, 0.05521008174977394, 0.0963875022950659, 0.14265707942371134, 0.13845283902026173, 0.10978209115586512, 0.14600725871611564, 0.23073468019982712, 0.31609366770654407, 0.368006200300974, 0.2174365937437886, 0.19079499985502132, 0.12708693172527985, 0.07620063906333066, 0.242513379568585, 0.22705456036633312, 0.1740654153576587, 0.18797518556147538, 0.3280598684944769, 0.42135847373777885, 0.4768636638352095, 0.048319751591287825, 0.10873072522345657, 0.18199510971908522, 0.06733282528297399, 0.09044556205144616, 0.1191032277428484, 0.16115121936809568, 0.14406902763876445, 0.21493234474495657, 0.2631533966663212, 0.06884063928225875, 0.1430541622150192, 0.05415795042325511, 0.056621664149724873, 0.07083109428762022, 0.11323465148868296, 0.14223231799325484, 0.23068671077071312, 0.2866613509095179, 0.07436760338478193, 0.11657379173372125, 0.100217349640361, 0.056567612323026636, 0.09079798028403528, 0.20100891945766386, 0.2960746644901428, 0.3542628967022927, 0.1876841265142392, 0.16514880711718075, 0.10559441912391869, 0.11267724588409574, 0.26744328746457285, 0.3663482123728639, 0.4265029246450939, 0.0351419772833049, 0.09266813053822792, 0.12485239802850709, 0.08807771674161267, 0.1795058101233452, 0.23885180198193814, 0.06289499110810184, 0.09049285852406411, 0.10233475253372, 0.20233567511976416, 0.2650922918255845, 0.04327957603928903, 0.16353862059199287, 0.2649853512394699, 0.3279836055300413, 0.1798097776962193, 0.2835673350692186, 0.3492873852824086, 0.10380618302340136, 0.17037281059345843, 0.06800456038684248]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "K" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.34770638196624637, 0.22953503488997098, 0.10583984852678009, 0.14026076165358403, 0.058001917589905326, 0.07380078987457711, 0.12434046217609873, 0.17547368699429808, 0.12686963313319333, 0.11669516111251182, 0.15081201773537795, 0.26275878749192777, 0.24950840288489312, 0.2914585306390613, 0.36760287520766505, 0.3939948989187025, 0.36159587941456717, 0.36264394250951765, 0.40269502440272154, 0.12668619326275155, 0.24203911636082762, 0.21478366067076268, 0.3222807930449241, 0.389382227653209, 0.45050782217895824, 0.21643052715410682, 0.3099757643865795, 0.3731776736483865, 0.4360735727622588, 0.23921107198071312, 0.28150108348401315, 0.17842352018688656, 0.11054322334892402, 0.32130636255852907, 0.3273480962394438, 0.24875639137194958, 0.18994597283285258, 0.1279152935034749, 0.09075158443262503, 0.19763517720589105, 0.26428739332279216, 0.3250706694571728, 0.14766759803014462, 0.22459123516367213, 0.27930349132406995, 0.3401955627542143, 0.22048995831989662, 0.24903470275146344, 0.18792035705593246, 0.19272503473107044, 0.34333521096500563, 0.33344149336649653, 0.27862742190241485, 0.2607146934468219, 0.05014065992390952, 0.0941722809303862, 0.15805112749638248, 0.21842815481133593, 0.09596356104224205, 0.11715789760202407, 0.15839152462847356, 0.2161640899795578, 0.19511587436259487, 0.19961971869411152, 0.2042919196729085, 0.2666256237503586, 0.3328432228933739, 0.30828057053551067, 0.28703139094838276, 0.31041407949863237, 0.1075184048608615, 0.1745992577613233, 0.235758515294343, 0.1257364162028508, 0.16635710717886443, 0.2081226107725527, 0.26470034211497645, 0.22258980397137115, 0.2352828129339768, 0.2171137452133024, 0.2594788733283287, 0.35890912632768524, 0.3387422738607569, 0.30566592830778555, 0.3141397289865713, 0.06719167614159195, 0.12847803819422288, 0.18518566354345173, 0.16509924091299563, 0.17041278111927413, 0.20870925732506962, 0.2815737185130024, 0.2772166552663093, 0.2976365166880407, 0.35914637458938065, 0.41784909938435244, 0.38928338216578756, 0.37759357757233847, 0.40458043797450377, 0.06130660213572117, 0.24233988145321755, 0.20064546540784914, 0.1831233804217016, 0.2017259213723727, 0.334008759184996, 0.32284858422872714, 0.35746371550532335, 0.42456700649102286, 0.4669197594003314, 0.435106827909162, 0.43288785017589426, 0.46669760602736043, 0.2989447946914401, 0.24627824405858045, 0.21505628404353158, 0.21640739594753128, 0.3869144954427955, 0.37152092066613457, 0.4147759060032671, 0.48504751310782057, 0.5165175907734136, 0.4826468427720027, 0.4869605325922662, 0.5251219311115568, 0.09468742737819122, 0.1598435156365689, 0.22234509342495265, 0.09928285225914318, 0.11005408133753052, 0.11598523708748298, 0.2009011938537442, 0.23701572951853725, 0.21390187500413768, 0.19242737872380644, 0.22755362821971434, 0.06577856746223344, 0.1277631016780795, 0.14859612478380443, 0.12588956700777917, 0.19495086342119805, 0.2917769905599798, 0.27085564188256167, 0.2363691948489722, 0.24891653890839124, 0.3062716836859475, 0.06290288914619627, 0.20780879739801617, 0.1770742289477975, 0.25915447534491304, 0.3574722857764421, 0.3178505484390859, 0.27973891737653117, 0.30579804074576067, 0.3693307511575105, 0.26171532325399127, 0.22576854984077033, 0.31744079919354434, 0.4182178661789018, 0.3586228642865809, 0.3182636047066272, 0.3559246711510834, 0.42557242355994823, 0.04566483631028962, 0.06705918581120289, 0.17445307759124, 0.13774146462644601, 0.11656701896243207, 0.10078202727508531, 0.16456747715404021, 0.11269134296661408, 0.2201101386184335, 0.14505105221481626, 0.11244779115195744, 0.13015676386570812, 0.20598087207029758, 0.10765866834903148, 0.15621173046798537, 0.15251857554736734, 0.09128185696969707, 0.11242449766526176, 0.22018150961709443, 0.2340542502126517, 0.14838601319476485, 0.07942535313940206, 0.04197682128239405, 0.07263740515609621, 0.15738923301581412, 0.08824824818165448, 0.181618771555219, 0.0941968049108488]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "L" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.3474454668893883, 0.23324293900094462, 0.1056984180255332, 0.34391364227760807, 0.34843449244671126, 0.3650704309116878, 0.3860757251645246, 0.4647896290400246, 0.4079936172197484, 0.3958791473121652, 0.4123200552218206, 0.545708781369653, 0.5112366416186367, 0.49290034199696836, 0.49884621791346995, 0.6333363984982808, 0.6227497412122213, 0.5908945709113848, 0.5718974027187876, 0.11645352624480736, 0.24440321187035297, 0.1681143721472438, 0.25716556493322545, 0.31558017161010277, 0.35902980075567176, 0.20346275629325378, 0.14394571723437707, 0.08219877601589984, 0.09556463611465799, 0.24860079100464083, 0.1925767872333033, 0.15625453783455764, 0.16198516582239553, 0.3156058511881172, 0.29238710861647493, 0.25057268701195634, 0.23042012284042301, 0.12866013127703493, 0.1600436261081763, 0.2216196923461898, 0.27120315050167787, 0.3113416997350308, 0.25647249418424956, 0.19328671281839127, 0.16540667475470233, 0.1820438368159693, 0.32648817649448675, 0.2834755039496923, 0.26040036504342, 0.2663486899509286, 0.4078183374513388, 0.3927394775374346, 0.35815143947173345, 0.33892232209124606, 0.24508411535954366, 0.26558764460706, 0.2947382566120436, 0.3242806193940301, 0.36264010505428834, 0.3041305642867042, 0.2901859081525759, 0.30662195986131946, 0.4416478560632607, 0.4057260432707335, 0.38736833356255373, 0.3933109824978365, 0.5282486430334502, 0.5170889508097948, 0.4854034910464694, 0.46652405608719705, 0.091887131181773, 0.15105132586468634, 0.19438400475512255, 0.12449268072848255, 0.0833789439244365, 0.12582823403707888, 0.13345615675538086, 0.21132826498944948, 0.19735932858712102, 0.20763934731151198, 0.21242757357113248, 0.3047998382226295, 0.3071132118143557, 0.295079862743406, 0.28141987431131615, 0.05917340274075876, 0.10258456829443666, 0.1792389682427678, 0.16411746599341345, 0.21685420144035306, 0.22299075913413874, 0.26565073684174306, 0.27003282876416657, 0.29086595050534886, 0.2950313098483238, 0.35950257578772105, 0.3716296030450938, 0.36996927777929584, 0.358931754345088, 0.04350955188856278, 0.22684414558623772, 0.22043161212958418, 0.2756542669082826, 0.281257054165569, 0.30932851806118555, 0.32147820614105055, 0.3463720740978582, 0.3502509077853851, 0.4010831055097452, 0.4178489162968737, 0.4211521226194025, 0.4114237755971099, 0.2629749970653992, 0.26164693601537725, 0.31849940094316204, 0.32364394654738704, 0.34212538759765254, 0.3591291846673688, 0.3866397535863895, 0.3903094452991634, 0.43175338549349745, 0.4515392358102847, 0.45821286467475514, 0.4494205789432536, 0.06405068595205866, 0.12272815787564574, 0.11371347179646404, 0.08835530712572046, 0.09734472083247357, 0.13584807256940323, 0.1377890901192531, 0.18282691831257264, 0.19239622205645082, 0.19532832184565582, 0.1875223337027108, 0.06903085622355765, 0.06690317429868686, 0.13772003259586416, 0.11435478356789713, 0.12685861093122525, 0.13119033162841123, 0.22758090281156754, 0.22549439288605438, 0.21171368038045107, 0.1983203531499323, 0.01663952573986745, 0.1686682438871332, 0.11863666370874977, 0.09871883668365604, 0.10455600094268948, 0.2433833108216364, 0.22745396432623732, 0.19640910209329285, 0.17850106359358284, 0.1535466273129735, 0.10211522307201168, 0.0833897446798952, 0.08913533060515444, 0.22687829519929786, 0.21085591022912992, 0.18059921780026286, 0.1630264849277513, 0.06539738011192889, 0.1199876293036109, 0.11789372000304996, 0.0945004882134546, 0.10969780595817694, 0.1300374061430668, 0.1304241582345842, 0.05476846799760567, 0.05317758056618449, 0.124764068860741, 0.11269029251580716, 0.09994464626105393, 0.09036351625329979, 0.005949264328431722, 0.1629138555597715, 0.13617517506273513, 0.09806756379374786, 0.07978683959223316, 0.15795836617723585, 0.13052445223125478, 0.0921367258533703, 0.0739480325202341, 0.04757283513081124, 0.10377347066758913, 0.11873260539761764, 0.05859051151091818, 0.07621060780894527, 0.020682208704127528]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "M" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.23518772307997304, 0.22716597111586112, 0.1416623581693698, 0.15376563171980479, 0.21850652674024518, 0.2614516759441517, 0.27210412067551426, 0.08101331950405967, 0.15477879851613155, 0.1941836946186474, 0.1896776533388309, 0.040931972958861106, 0.0678127967580848, 0.10930877139291534, 0.10789659889709546, 0.1381850705635492, 0.014261937877010524, 0.08717715342914943, 0.12504264497216006, 0.09972234256279197, 0.15171015610386934, 0.1417418352273334, 0.19629389821837007, 0.16957439725050838, 0.11669583604584327, 0.16831830856504437, 0.20014156479387996, 0.16638094264178516, 0.09468925061824165, 0.22048295803284046, 0.2193694669573809, 0.16958166479308817, 0.12733562490928688, 0.30396371310829995, 0.22380024233756735, 0.1591890488648002, 0.2008821471646374, 0.09515423067930576, 0.08123993263566695, 0.10165677212011662, 0.07098266463728972, 0.0449795010783093, 0.14638573940595614, 0.12768753797897686, 0.07839881903551356, 0.03829639005724331, 0.23015208553853564, 0.18397260888429728, 0.12640681744618062, 0.1353987330170322, 0.3343691230329832, 0.2205579016413708, 0.18147429301369256, 0.24657243567378967, 0.013929372462489509, 0.08643049777498704, 0.11986714649005521, 0.1377223119223651, 0.06339242580188237, 0.051128704752033405, 0.05543526305112133, 0.06531957447056404, 0.15568005971248275, 0.08970145082946136, 0.033141652510642036, 0.08539431828711426, 0.26635079611843476, 0.13845055901711167, 0.12649895760265098, 0.19983154259100583, 0.08162732976021175, 0.10857489530639923, 0.12384759410528495, 0.07409070416072687, 0.058586032012022914, 0.04834962630424671, 0.05244510290750586, 0.16567373461432175, 0.10349049489709854, 0.04647213584524422, 0.08875915980928425, 0.2757475515229533, 0.14984727820355845, 0.13225391261063443, 0.20513768678035743, 0.06471619645581665, 0.12147502584265188, 0.14720131094973088, 0.06685597383498897, 0.03442773453182505, 0.10408295843076608, 0.23889648930886928, 0.15502836276022672, 0.11222080617936406, 0.1703376914806705, 0.3499998260943171, 0.2182426049742769, 0.2128586014640161, 0.28611397757278334, 0.06682584354724055, 0.18264619702010365, 0.1237250255836143, 0.06991192909225169, 0.09690657939624218, 0.27404506719508537, 0.20466911542072716, 0.1522598856015841, 0.1889615232255812, 0.38345316698154847, 0.2582364459032266, 0.23522960308863974, 0.3053718848368604, 0.19125346999914525, 0.16330506160158667, 0.10890490168920201, 0.08307078434704503, 0.2748048735549918, 0.22729579144591597, 0.16992098583785162, 0.17907657988704004, 0.3779013686555352, 0.2655357043292918, 0.22460741125362088, 0.28720109132039395, 0.09276163559537237, 0.11843821224347735, 0.10934875579544416, 0.09236745944057745, 0.05237782952736987, 0.03560385558491286, 0.051414787055394734, 0.20327146074375346, 0.07591915085564711, 0.07385434431821335, 0.14536291797945783, 0.05579111711576448, 0.10808832211761801, 0.17965408510461678, 0.08911642928307077, 0.05798775255976301, 0.13045238619426724, 0.28993257270682443, 0.15626692837122433, 0.16536908667598454, 0.237909771825877, 0.07225024150568608, 0.21080278313608453, 0.13506599834444624, 0.08517757939046075, 0.13697443036792922, 0.321655243608581, 0.19229228903465656, 0.1805380573561967, 0.2534857958552338, 0.1918575629440946, 0.15029669033894458, 0.09316438095668107, 0.09760298401273372, 0.2964369802408819, 0.1826600885578988, 0.14395947684523538, 0.2108593908778885, 0.10013027802273682, 0.12668197839075304, 0.09820076814768439, 0.11110447025028072, 0.029161487358848822, 0.062099681332987045, 0.0843961127129835, 0.05757229706746061, 0.10269267352784665, 0.2057785956076116, 0.07265472347529005, 0.11223030107098797, 0.17444855888829375, 0.07482937426408735, 0.23778639347732813, 0.107122286782454, 0.10738241062404442, 0.1800219822528828, 0.19897645527877705, 0.09691571530239554, 0.046559658525560634, 0.1171805512559781, 0.13400456541870198, 0.15339052113507404, 0.10650237032977042, 0.07330830295414575, 0.11202046704196549, 0.07338551349920333]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.055)) {
                            uiCount += 1
                        }
     
                    }
                    if currentAlphabet == "N" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.2548560737326484, 0.21036257712807377, 0.09281171754508263, 0.14685934313655327, 0.17992396926360915, 0.2137532875878299, 0.24520412223645224, 0.07352402003031328, 0.09021647593527662, 0.10794166922273894, 0.13371133104399374, 0.1083027573815775, 0.03963660868850528, 0.11708189698113433, 0.20290546456828856, 0.23853730314819385, 0.1397914398230275, 0.16950826488940685, 0.23274008907679328, 0.1273459853679286, 0.1802184060182953, 0.17931993949902658, 0.23900388885850762, 0.21050355897254744, 0.15327192694364594, 0.18493600361447352, 0.24139555241775973, 0.2190621739079501, 0.14878660492440596, 0.22020396341920664, 0.23145618366097195, 0.14935754030715992, 0.06805657020526003, 0.31446337903066324, 0.2650349501946744, 0.20092814813206178, 0.1696777968370039, 0.11755142255804339, 0.07586954373179076, 0.11819596516158248, 0.0832948358244155, 0.04166925856151583, 0.14044612462030834, 0.15457242749689482, 0.1269134768185855, 0.07708866153975395, 0.2351782673276563, 0.20718648498027772, 0.16030165841220764, 0.14475396805515464, 0.36576754621312724, 0.28685742285510335, 0.2505346018773413, 0.25567084485301494, 0.06081365836870861, 0.1157252644495775, 0.13312671880702187, 0.1531861254719277, 0.02836261418755527, 0.0648709207358726, 0.05227155077911697, 0.04122345672979981, 0.14140085602751606, 0.09427596818247441, 0.08969198971352704, 0.1458652333425226, 0.2824939372519088, 0.19039601285683844, 0.18099140139299302, 0.21930180893810533, 0.066810756554184, 0.07252407663413128, 0.10167309026465972, 0.08908981396308306, 0.07912627800161791, 0.05127076909532815, 0.042003389995022206, 0.20074989139157043, 0.15447185200421387, 0.13955182913966827, 0.16777586047167514, 0.34081405803856873, 0.2506021835565856, 0.23435715759444736, 0.26152765439174486, 0.05186119519120505, 0.12189591312225685, 0.14259510603847167, 0.09112295378505006, 0.07314349733751102, 0.10860033989660806, 0.2559183166503527, 0.1994373691963124, 0.2027477931092928, 0.23401488260687997, 0.3974012577895716, 0.30299178337493393, 0.2962262199362557, 0.3276938924258747, 0.07414927805384482, 0.16147651554968734, 0.13152205715600085, 0.10706512167294872, 0.10930590813408644, 0.2731396883896736, 0.2257573613625913, 0.20903488231169937, 0.21972842560698672, 0.41268469980784156, 0.3231233278758747, 0.3040415569693712, 0.3238886004099083, 0.17813166932881175, 0.1796560239507409, 0.15185562496036129, 0.11472939999171085, 0.27642650068099156, 0.24547933652904566, 0.2019325158751838, 0.18189234883914357, 0.40741799143297547, 0.32810736795565193, 0.29202233931726956, 0.29454940576648064, 0.07820827810262616, 0.07433970254517995, 0.06355034741045583, 0.11353766329994971, 0.06744697852240593, 0.07014494790414544, 0.14085041114118937, 0.2549029759502181, 0.16211011770508443, 0.1563981343204081, 0.200670593901909, 0.027905077746172333, 0.09329426097723169, 0.18043651505255337, 0.11588361260580175, 0.1483299777251923, 0.21071561971720373, 0.32004675094352253, 0.22237387680718007, 0.23146189027272146, 0.27887762995438314, 0.07031598831342432, 0.18531164459396782, 0.1264088227508512, 0.14160830977035957, 0.19407539233958196, 0.32662644873045243, 0.23088830788368872, 0.2307309342495396, 0.27155311262219756, 0.16662928101755817, 0.13076767239069126, 0.09973553886071714, 0.12799028342168065, 0.30421677118524393, 0.21777582387114214, 0.19476106385750663, 0.2195424012687815, 0.06945858018571267, 0.07765821103713347, 0.15363464078457365, 0.14150056331280433, 0.051682952408120694, 0.06364887696424172, 0.13489740457139365, 0.08553500338899155, 0.1739194238585121, 0.2047664932880117, 0.10657590825002143, 0.1298962724655224, 0.19378842507388408, 0.08855815081570204, 0.2063744748546621, 0.1284937952432185, 0.09503806702629122, 0.13062118453918017, 0.24867101543949174, 0.19718941838915116, 0.1335492636556062, 0.11395205731312279, 0.09876752741068401, 0.11711619432719954, 0.15626121421607125, 0.07672038745368528, 0.14990559512292823, 0.07469664371224985]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "O" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.35392203008261547, 0.2145356130887271, 0.09700951006784798, 0.26389612951855973, 0.1942421625873744, 0.089053702435152, 0.026427979978138668, 0.3191281351436458, 0.2288613868470085, 0.09404388600243262, 0.020726791046094793, 0.3821150901966974, 0.2716535396546899, 0.11925305174398725, 0.02691148418088773, 0.4188693355626841, 0.29006284432655594, 0.17262367738395898, 0.07366483484255244, 0.13942594715554185, 0.25831036990795225, 0.20557976339027964, 0.2817624972536348, 0.34152396619891756, 0.360695006415078, 0.22361456819065584, 0.3028767590054784, 0.35079931618190957, 0.35705896748762994, 0.24841952972974377, 0.29387725177929286, 0.3457962947235822, 0.3563035152996451, 0.25091089352951296, 0.26918697689711063, 0.29884520307020057, 0.32563617724360855, 0.11907769672442103, 0.15471006976674342, 0.1840664570597062, 0.21063546635026134, 0.22218806791024928, 0.20383336458729953, 0.21757243366964021, 0.22057795490764898, 0.21829546487882898, 0.25742383859882617, 0.22946352789664193, 0.22086151558784528, 0.21788738597810828, 0.2804665771533221, 0.21972595471524192, 0.19163322295382415, 0.1919574613258866, 0.20473433576287564, 0.1696713287976249, 0.12353213970710496, 0.10933846360965979, 0.26224413221029463, 0.20958836341058826, 0.13363626792750583, 0.10442866693689926, 0.3245856179074851, 0.24250888374322177, 0.14656350221707584, 0.10559665577654781, 0.35691912555161365, 0.24992891011668683, 0.1595442096995761, 0.09985722847166405, 0.09755546374630883, 0.2033304353629219, 0.2549942395325395, 0.05751909799311035, 0.10317578560005512, 0.2086632472499537, 0.254773645934226, 0.12029337639166501, 0.08836005603596511, 0.1909840555162087, 0.2505546071257615, 0.15521358043108052, 0.06774333831360056, 0.12292811667675407, 0.2007483333473094, 0.11676730008732968, 0.17849893012381077, 0.13919167526207563, 0.039956137843900036, 0.11952146085885526, 0.1800451816470855, 0.19824234019867376, 0.07766672758588178, 0.09780289259359425, 0.1746070389388932, 0.2380222710202827, 0.0975257124636851, 0.026678492987302627, 0.12210660874268818, 0.0668844269537168, 0.2530345809685525, 0.145897209890142, 0.010341552895524896, 0.07031376105506301, 0.3139713028410702, 0.19092524262358848, 0.030333317006171538, 0.06402912306052995, 0.3530771945960834, 0.21418665331728923, 0.0915410393050087, 0.023924407913454935, 0.3086389553503575, 0.21093789039994473, 0.07032104457859133, 0.006164299340710753, 0.3711098172777917, 0.254973755716051, 0.09630885692578586, 0.004618759464351635, 0.40887772375532583, 0.2756057042413932, 0.1551922886649906, 0.05644857069286307, 0.12890061909438988, 0.25716715669112017, 0.30886141144560303, 0.06319631758974108, 0.0936151885160339, 0.23680239190411387, 0.3043057834761197, 0.10031752228443666, 0.05953672209584409, 0.16586861703917932, 0.2532293574837821, 0.14644067168922872, 0.2131712871012923, 0.18105058605646887, 0.045959992302243735, 0.1216538955099643, 0.20737255500561222, 0.22177380814871006, 0.07540421194514917, 0.056267807854988895, 0.15543697362110293, 0.07441697240323852, 0.31750225271018934, 0.1919505374353179, 0.02631777909920939, 0.06801466592468143, 0.3569242190038043, 0.21646186612175225, 0.09357762639997295, 0.033817077668177216, 0.3714955595376602, 0.2568653657839507, 0.10013125124616194, 0.006415688277547211, 0.40901619677822165, 0.276873135108959, 0.15721073784058712, 0.057988480174043254, 0.13852369508342033, 0.29595038699190435, 0.36682299977405874, 0.04076698789345162, 0.10571096951575304, 0.22474063990934312, 0.315365044489015, 0.167465874966545, 0.2512431780114928, 0.17923620112849623, 0.034479899723171725, 0.09982300397640881, 0.19889043013331542, 0.09377047771919218, 0.3358195117392952, 0.19334517982919006, 0.07121427253808835, 0.05141269894968861, 0.4045258477286521, 0.27160932709819174, 0.1515117757852104, 0.052502229304567584, 0.14646581053157337, 0.2646185563428322, 0.35354509436743253, 0.12288892541835293, 0.21915764437029592, 0.0993274074363557]

                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "P" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.2920748570193241, 0.19418279249984463, 0.10549911628201065, 0.1687770950228861, 0.057898975507860384, 0.0726638141441123, 0.11965042278496126, 0.20172108516884213, 0.10750001471214543, 0.09588963565325095, 0.11831399985503845, 0.24377316805990495, 0.19632443833699087, 0.2278515297194638, 0.26201817752236345, 0.29154755063638926, 0.25549747893472446, 0.2706435841655053, 0.29686117981094456, 0.09789463837630127, 0.18659739458122301, 0.15226143288825442, 0.26554237622942034, 0.3458606366036541, 0.4027350777018216, 0.11861017707418535, 0.18605759129773203, 0.23076088001856893, 0.2728848802724022, 0.07212933098160251, 0.10673177426259496, 0.1150869327094541, 0.1284883853807524, 0.018243704735742935, 0.0631140827964614, 0.08642558731081759, 0.10718034875047967, 0.08870383903590927, 0.07664806364292126, 0.17011094248523123, 0.2494534635490296, 0.30587795393062045, 0.06252801027203743, 0.08885877160823001, 0.1398251642767844, 0.18793242548284375, 0.06565869257592766, 0.03908637258888439, 0.0854019060678986, 0.12292627116325526, 0.09838908569609671, 0.07466047196116225, 0.10295405193386199, 0.1352346237230606, 0.08163306713349355, 0.08809869672848161, 0.163444363905293, 0.21877472446778445, 0.10574162839634058, 0.01593553171131629, 0.07515339013572969, 0.12858622015840368, 0.14140885480011448, 0.0958601440756676, 0.13621137241960093, 0.17474406894953382, 0.18622558646833562, 0.1537063848286493, 0.17344809402677885, 0.2028075809752599, 0.1252993910259411, 0.2052587634288613, 0.2625622709589823, 0.03666344050908856, 0.09419296442430511, 0.15621443133612564, 0.20971760889459887, 0.0856238387499018, 0.11145861183488774, 0.15996297148534605, 0.1986890238741761, 0.14419823416992025, 0.14926135709194405, 0.17916107070966458, 0.21149170437136094, 0.08087198896286657, 0.13825361878688203, 0.16117333035307488, 0.09835896660806735, 0.12040815292463093, 0.15967873958704865, 0.20779470666505995, 0.18355765629448317, 0.22401299354964138, 0.2620103838818303, 0.2617128778346374, 0.24024557294595653, 0.2613771862559447, 0.2909057860651062, 0.057417202993980926, 0.24152136304456534, 0.17009593828111363, 0.1684383093043595, 0.18764418817530784, 0.28859234403274664, 0.2589171881581841, 0.295094440885535, 0.33097230802056843, 0.3424502127616427, 0.31714731851793304, 0.3356876473938498, 0.36361663077983797, 0.2988875196864946, 0.22408475243906, 0.21343992132413167, 0.22180383860741698, 0.3460073185397884, 0.31337702662887396, 0.3471879088110148, 0.3816669568213808, 0.39963867620623555, 0.37211191580208897, 0.3891936978602341, 0.41611738304840923, 0.11489536354952495, 0.17607829130539657, 0.2287292596852946, 0.049382294258812715, 0.1015301928761105, 0.1473966527523989, 0.18359386699681934, 0.1090153885672754, 0.12582596895616122, 0.1577055308593274, 0.18963231841221406, 0.06212761010297123, 0.11557871444756265, 0.14648527796175892, 0.08932237171807854, 0.1260475931488851, 0.16367951080915483, 0.1872437968233239, 0.1482898399029822, 0.16559172242669687, 0.19387178976265085, 0.05351015901220347, 0.20298055088687628, 0.12472422703916224, 0.14276210939422115, 0.17222293273071915, 0.2355000818456976, 0.18114702123975104, 0.1886082106153018, 0.21069944585218964, 0.25270815958949777, 0.16635304683221713, 0.1719316258134953, 0.19284089966777898, 0.2797729469020742, 0.21761868063006504, 0.21829125309880273, 0.23475056026598437, 0.09871784941106732, 0.13425041365662, 0.16399618988096154, 0.06037661345555549, 0.09734015052647697, 0.12990453017372222, 0.1595241817914123, 0.04860102252871734, 0.08790780196952036, 0.11361058705498424, 0.059204933554546174, 0.07792344815463415, 0.10842956241958135, 0.0397490488343113, 0.12814756289458515, 0.05220191617328182, 0.046514477872425596, 0.06903152863868708, 0.14462270614648598, 0.06917081641323092, 0.042542561914037325, 0.04291200597225118, 0.07726818150918736, 0.10310960776123299, 0.1251158491082956, 0.032718048582253176, 0.06390336074179827, 0.03233079518024446]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "R" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.2906621804072326, 0.2193792332617597, 0.11588933937184923, 0.10407182307580501, 0.09199881544636707, 0.12461336142881287, 0.1638817080343561, 0.06034375307789983, 0.03487278752824325, 0.11459357938957838, 0.17686851598862494, 0.1697355339674179, 0.08902037092107437, 0.09796594064847113, 0.17652712377459748, 0.2741424629660779, 0.17655184906136873, 0.1720849516717786, 0.22642358175456423, 0.1299706809938385, 0.20991384341465555, 0.23896090957099936, 0.32152460468141797, 0.38261462470151164, 0.43189994223850975, 0.2392286167274295, 0.32217622006551655, 0.38575325132899224, 0.441675793448356, 0.25872040573360716, 0.2972231170232957, 0.2018354969683801, 0.1147124771051567, 0.30565054475135206, 0.26950709484868995, 0.19021140312713217, 0.12552895635535188, 0.10879333811978864, 0.13382384384988202, 0.21701201334392398, 0.27886880785981044, 0.32852216064302975, 0.1894200403484796, 0.24256725366766643, 0.28773763923060325, 0.3361091651234537, 0.26985123067232614, 0.26387801243780024, 0.16588423651056075, 0.10368944563615563, 0.3520180814157958, 0.28176970234530074, 0.21043039779158876, 0.1854102827815894, 0.029081032940703813, 0.11247843436477006, 0.17438241732209345, 0.22414016527268416, 0.10585588349648156, 0.1350006072037887, 0.18072938203093775, 0.23305243991875907, 0.21984906039249807, 0.18005054316916264, 0.10394377272155532, 0.11478813780439756, 0.3197019617209947, 0.23068171754659803, 0.1823238567950131, 0.19853399309290964, 0.0842190667257679, 0.14629463061215395, 0.19610360846500074, 0.10998612343096233, 0.11663461179429699, 0.15396667372876371, 0.2046625086788647, 0.23094498362711394, 0.17932169268472692, 0.1178978560687196, 0.14233729068372228, 0.33353909120128783, 0.24111871235965499, 0.20059568232188718, 0.22355777470625293, 0.06208679901254983, 0.11189475775511865, 0.13845501920838954, 0.07567422096367954, 0.07212286936452979, 0.12057413013908, 0.259182370303897, 0.18070646055721146, 0.16596577518892555, 0.21810067122970783, 0.3642876954373448, 0.2668652671729737, 0.24972668849034058, 0.2897105431789404, 0.04980934217495613, 0.1819942299378592, 0.09363909305451279, 0.023868682391114414, 0.05909435071986349, 0.29282944684891704, 0.20386136710068092, 0.21525793775345894, 0.2766531525821581, 0.3957234708192491, 0.2986559672666381, 0.2952821339493517, 0.3428553090772015, 0.2236056283172287, 0.12983384758365704, 0.04949892633774531, 0.013874800938416322, 0.32627000176477994, 0.23334884834730185, 0.2590326906301107, 0.3247014114875417, 0.4262182863415684, 0.3308047346739058, 0.3359548255909525, 0.38762577001082094, 0.09520915020788638, 0.17413942257146908, 0.23634551918113939, 0.12413933711792179, 0.07582672753977876, 0.039038627369277844, 0.12470668795603049, 0.22898677062183442, 0.13335475731416857, 0.11330788202703042, 0.1662802498022146, 0.08099540870437964, 0.14306043917536534, 0.19925131135271737, 0.11120198270900448, 0.13268384488760612, 0.20889238093814325, 0.302159095928688, 0.20501889242967195, 0.206317374661827, 0.2612671525300651, 0.062278399900150175, 0.2792167486331754, 0.18789483898116735, 0.20957355581303586, 0.27686760267447746, 0.3806816580589325, 0.28433264034796557, 0.2866691569058584, 0.33823150969797544, 0.3399741564759915, 0.24717217428565869, 0.2713687060274253, 0.3355082005459048, 0.4400582203244955, 0.34457277752265625, 0.3489472961531437, 0.39977761367607295, 0.09499737764447798, 0.11615411678374167, 0.17079164890012685, 0.10522189854369392, 0.011929568897081563, 0.06858269540907773, 0.13881187165903747, 0.10074254646998194, 0.18716245502106987, 0.19294076960264878, 0.09802644679908941, 0.12847709577119373, 0.1994655876126481, 0.08825531282535089, 0.21619038215959185, 0.12723345671057357, 0.08489370392046702, 0.12883073095891637, 0.2483675395075692, 0.1826668782153993, 0.10761770756801767, 0.0893335379672308, 0.09759465831373007, 0.14285713936154054, 0.18162416350617214, 0.07966027673115281, 0.14850230182935414, 0.07389269475116579]
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "S" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.21044855428096151, 0.15295067330990014, 0.13271657320527502, 0.06553569776866731, 0.03938750781980462, 0.08066007361506013, 0.09532594973777742, 0.13206496758745107, 0.06575159763014402, 0.12593611509536928, 0.1605339433024276, 0.23133389800040405, 0.15786335105029284, 0.18559177527433873, 0.22969708764055272, 0.3640281448647218, 0.26892993321435793, 0.25255562084143174, 0.2966423434733597, 0.1244223157400365, 0.21950567411705804, 0.14495995855771326, 0.19386487876856404, 0.15121116813285423, 0.1186958967880484, 0.18046186570093295, 0.2041013531235442, 0.10174133634791156, 0.12022946729474385, 0.2473285247263199, 0.23135068776756856, 0.14915259604671408, 0.17353053628311935, 0.3544666493567202, 0.2872539522363327, 0.2191938251552528, 0.24496520902184094, 0.0994552558355455, 0.1052222314152948, 0.11817413650345752, 0.07232632531023822, 0.07657287760661889, 0.20922451752057095, 0.1871139208945664, 0.13278445235628425, 0.18089343126026253, 0.3060890627039148, 0.25793746524055133, 0.21793937178729406, 0.2576368990425495, 0.43265280172712617, 0.34861091440533915, 0.2985223810893581, 0.3348083816752223, 0.1307969431532238, 0.09538344117830456, 0.08941537818511766, 0.12504495699136595, 0.24385674336571816, 0.19296366381037214, 0.19199985784932627, 0.24132837491584444, 0.3472818097956232, 0.2820911895865685, 0.2762124128101109, 0.3203931926284338, 0.4801004891534395, 0.3881212311656138, 0.35458605604814547, 0.39579428030342684, 0.05599661997608542, 0.04380162258448777, 0.03277039613544197, 0.11455330312950301, 0.08195120058833813, 0.06952067139462323, 0.11460765416359925, 0.21746731376600376, 0.15800592031898258, 0.14726213546291927, 0.19210609776514698, 0.34971844071748837, 0.2589647873439119, 0.22417630504209515, 0.26606824198718987, 0.0481837188965155, 0.07519618511936706, 0.15477169464038876, 0.09784583800315791, 0.12536913294798965, 0.16843320653477326, 0.25747556402883787, 0.18838520592260563, 0.19871446703331389, 0.24371006441591353, 0.39081863020567936, 0.2970082498362492, 0.27199040910952965, 0.31517341633275764, 0.037821661427162596, 0.1583111631566831, 0.12030392126613704, 0.10306131162539443, 0.15201472439213018, 0.26101234158942155, 0.20136822917164782, 0.18680428802302673, 0.23099898968343172, 0.392887460128759, 0.3026482671705994, 0.2654777018106224, 0.30642418210747185, 0.1339583823923572, 0.11308840329658842, 0.06730862443562387, 0.11715679860753628, 0.23377446525916715, 0.18162550519938694, 0.15309936029253834, 0.19640289108302145, 0.3635850065174362, 0.27606617118829285, 0.23305534320434537, 0.2727423765691306, 0.07186362705260466, 0.08486763793180885, 0.0663101308605276, 0.10344164981360554, 0.0519996701655416, 0.06680299010049744, 0.10438391533863253, 0.2365524583183801, 0.1444856132461188, 0.12080582864106792, 0.16508012127236446, 0.10383060196213631, 0.11882746471653448, 0.1663759651697036, 0.09212561547347761, 0.13422307429916777, 0.17530786388758024, 0.2985758103550435, 0.2032957903507277, 0.19200128836575123, 0.2363415262738016, 0.049992887102834886, 0.17401819403201577, 0.13683091626475616, 0.08651227701518814, 0.12917223449563975, 0.30000162223101007, 0.21652280132746068, 0.16705879361049547, 0.2057838721772965, 0.13112414692348953, 0.1134165150229302, 0.03704810614521177, 0.07924816322477723, 0.2521544137787705, 0.1729553136621066, 0.11770011306204439, 0.1558006087419725, 0.07867547031899452, 0.09821340881776372, 0.0868653214075107, 0.1333434973319825, 0.04253006656142479, 0.05589488403350475, 0.08905536587751599, 0.10016017235107881, 0.12238766392554477, 0.2076112632647082, 0.1119375796015801, 0.11885648147082502, 0.16095671443464035, 0.04501251103942378, 0.21531664544926768, 0.13884005095076538, 0.08068109989472345, 0.11972220239538865, 0.18131585577043857, 0.11964090598122024, 0.045742739324332087, 0.07719615061544531, 0.09570690028194073, 0.13634084549647588, 0.11300279971036052, 0.07810085932592811, 0.09187166140924406, 0.044340241286759716]

                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "T" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.22202057300022002, 0.22572452635030324, 0.1458993791632554, 0.12191802536594816, 0.14557418674930164, 0.17037483640462278, 0.18974930249419605, 0.02429051218499498, 0.061018087065968805, 0.101478752484425, 0.14389335598811118, 0.07396730672260082, 0.06371578241799097, 0.11827108547512169, 0.18507657876947445, 0.16159063050496322, 0.13581420273492292, 0.14330413410612994, 0.17254671855491122, 0.09887160969818909, 0.13403209808475317, 0.19117147784189512, 0.24690742671423135, 0.20053635697882213, 0.14855535067116746, 0.22009004229953613, 0.2368394137150133, 0.14653048480884207, 0.09123640606507477, 0.2674106200044727, 0.20924392006594064, 0.12884590981533486, 0.08448519735489259, 0.3232845327182936, 0.25823039521097213, 0.1895665320973365, 0.1490984241954357, 0.08609495605880954, 0.14176946774304772, 0.1882133340560267, 0.12809309184658685, 0.06753589485965908, 0.21339845819084843, 0.21381493253667844, 0.1255086327897401, 0.08805156484365856, 0.2900937613511402, 0.24058614461950684, 0.18064996914647158, 0.16831386134963167, 0.36397414838005115, 0.3079246053961994, 0.2528915698237335, 0.22595436089704496, 0.05967236836807399, 0.11350311611993141, 0.07013528819745003, 0.0468450795474544, 0.13041458458941033, 0.12779115332278354, 0.045027383937910344, 0.05171728831217015, 0.2157029612263352, 0.1744913888324233, 0.13995700716889758, 0.16236397022731927, 0.29678049856706407, 0.24957500639490302, 0.21067141727622032, 0.20106365446892854, 0.05647670859210659, 0.048468356059785035, 0.0828036338683032, 0.10000456684070096, 0.0820594193441072, 0.05600411812424997, 0.10202819544795345, 0.1958853306223364, 0.16976315619612378, 0.16475661121730648, 0.20496301809227363, 0.28302919413129873, 0.2479818848764098, 0.2265956304099925, 0.23019213735325028, 0.06445222203586984, 0.12236942483955981, 0.1212863716157097, 0.08805857591608643, 0.11056798932605638, 0.15846773109898674, 0.2158816893562113, 0.20394645684800003, 0.2151212478335518, 0.26016979268377244, 0.30438021885908356, 0.28042847964111856, 0.27088889078112727, 0.2807083766672241, 0.060622985378759, 0.1482350245033233, 0.12686344780782643, 0.09307208051255159, 0.12175938137406392, 0.24434084778875095, 0.21688410921328902, 0.20229948627875122, 0.2319609378231527, 0.3314624804929268, 0.2950225505123331, 0.268635574766017, 0.2662596262004514, 0.17213690049145822, 0.16277356706986415, 0.09100245045095584, 0.08788052752710032, 0.2611052358036615, 0.22128354119348334, 0.1834310404137526, 0.1958171626545221, 0.34326579193775414, 0.29636762993399235, 0.2553898774937593, 0.2415561046116797, 0.037942464260514404, 0.0878898712241521, 0.1363155814502772, 0.09679843726989573, 0.08600190794688256, 0.12846625245702367, 0.19236727165896736, 0.18503644040231468, 0.15986776533346983, 0.16269267627658196, 0.18735287135462592, 0.0930044253136123, 0.14762787531635074, 0.12801252870109323, 0.1239013367948715, 0.16043243211044225, 0.22050616484613866, 0.21641196326479567, 0.19663716786839416, 0.20005571993175844, 0.222034024331479, 0.05555549060541442, 0.1706756191413032, 0.1309445178972775, 0.11000607396477506, 0.14960358946102675, 0.25228747626681597, 0.2074400206315393, 0.17565399800710702, 0.17497744067530124, 0.20356065493310835, 0.15260254988234684, 0.09780822379945464, 0.11082804798175977, 0.27592406117457474, 0.22068685296810928, 0.1707600777217156, 0.15370262738567608, 0.05937392360320852, 0.1431454721168866, 0.209832746589309, 0.08855472599726844, 0.08254653873180737, 0.12778258457103414, 0.17369530081181356, 0.08377240139284081, 0.15074630454621896, 0.12363220035947836, 0.0782196877654377, 0.082226996434551, 0.12016096482704114, 0.06838842521556965, 0.19461305746880375, 0.13120949382053523, 0.0730103604968603, 0.06563500263527963, 0.2505922367764668, 0.1826863208013447, 0.10950493503653123, 0.06485500788787678, 0.06896548084139674, 0.14432072982918845, 0.1961730471971675, 0.07536264775412951, 0.1272125697275839, 0.05196452684173514]
                        
                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.035)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "U" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.22127797685333095, 0.18605207904477217, 0.13036539264849525, 0.058780289212000875, 0.10382684422430499, 0.15767009969049395, 0.19947498762841262, 0.069209013074, 0.0849830085231165, 0.147495541180222, 0.20453388861425834, 0.19939925227768426, 0.10570794983222809, 0.11738519572028984, 0.17597882674157622, 0.2917217500625161, 0.20261552793548473, 0.1726422690561603, 0.20801889063327464, 0.0958548731835689, 0.15831939812524168, 0.20202532079826982, 0.2925290262348113, 0.35545659640217314, 0.40697918272283806, 0.23581189856131396, 0.30586170295281034, 0.36814060978522545, 0.42480432058354395, 0.30017537402949374, 0.2491872344764547, 0.13823766468480858, 0.08086957517698591, 0.3529633344099703, 0.27914759991794685, 0.17521151079176553, 0.1079824889490252, 0.0766689909768937, 0.1444447291843918, 0.22654097953961796, 0.28778766987426263, 0.34229734598997047, 0.22766527937640077, 0.2678897247324722, 0.320616869438791, 0.3742752521528704, 0.32745073988930457, 0.25322063611745765, 0.15940212976507523, 0.1386411248719142, 0.3986428199562213, 0.313850883972711, 0.2220513632236916, 0.180900409924912, 0.07699788242558064, 0.15089103479767343, 0.2114226200877708, 0.26618720999039325, 0.1877885983070702, 0.2039602153536223, 0.25015331282995495, 0.30183881837503684, 0.30659567606862936, 0.22002484530745994, 0.15578843120031882, 0.16776090544274216, 0.38941663329066917, 0.29987069587818194, 0.2267310341074796, 0.21242346739222825, 0.09089137286251513, 0.15368412063088535, 0.20503502534907697, 0.12543158549925815, 0.1269759090966594, 0.1761769561928874, 0.23013051513732527, 0.25368475441495064, 0.16116255401766294, 0.13699053594781044, 0.17866416631274074, 0.3435744518573348, 0.2533738606979688, 0.20416354415539625, 0.21855050688600305, 0.06292971532166255, 0.11599076136344838, 0.1641500342028498, 0.09903492138050936, 0.11143811576305367, 0.1553805048293255, 0.29054505614471715, 0.19893882314981995, 0.21681519979625846, 0.2668664610698721, 0.38515929684814515, 0.2991691026707019, 0.2762430409058606, 0.30427540959217997, 0.055325322234516985, 0.20735553963055908, 0.11852544860481345, 0.09055242555032814, 0.11302116653845397, 0.3244488438751993, 0.238556917434962, 0.2743491857084917, 0.32774358434989875, 0.41885813504126557, 0.33775137922022747, 0.329097463746722, 0.3636427637832878, 0.23805939063440634, 0.13991334447521095, 0.0849471606937529, 0.07569904675482211, 0.3428756825202959, 0.2648398452726077, 0.31672809405560964, 0.37406001010486406, 0.4351879960211081, 0.3601493870684191, 0.3655789434760874, 0.4074897356094761, 0.09984177710404887, 0.16658323498436373, 0.22092208726483253, 0.13029700839413133, 0.03653404883695442, 0.10292300079973593, 0.1703321023328373, 0.22332542917880158, 0.1354007245307687, 0.13024845486152575, 0.18890660571992132, 0.06774347160798644, 0.1240505552775886, 0.20639317346889818, 0.12492680439655059, 0.19083445504995716, 0.25505948625682034, 0.300522111924811, 0.22137234699018185, 0.22972404367955693, 0.2815882890262958, 0.057124961714247996, 0.2600365942966428, 0.18802197259255785, 0.2581731725734882, 0.3215075859909093, 0.35124501056362234, 0.2790673562217047, 0.2968109740089444, 0.3491322248580329, 0.30253270012531447, 0.23905736221441276, 0.3148665452577205, 0.37855734262374746, 0.3898151587997595, 0.32439844047830846, 0.3509806442932683, 0.405622275037349, 0.09376832817769006, 0.16956466211019652, 0.21974370489213518, 0.09479256643609132, 0.03047950496020951, 0.1293635642843478, 0.2098791833305641, 0.11121352596495084, 0.17655733197291015, 0.1871120727151036, 0.10030532821476508, 0.1165955162253804, 0.18655594353397773, 0.06741680566298285, 0.2399740313830354, 0.15448028134405462, 0.07119441145926408, 0.09126910075167421, 0.273323729385933, 0.1982873269591595, 0.09458524942410437, 0.04478191005761191, 0.09036236251822402, 0.17936284851647194, 0.2490545700769368, 0.1050740640703278, 0.1843243820716339, 0.08076065763247592]

                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
                            uiCount += 1
                        }
                    }
                    if currentAlphabet == "W" {
                        guard
                            let thumbTipLocationH = firstPose.keypoints[.thumbTip]?.location,
                            let thumbCMCH = firstPose.keypoints[.thumbCMC]?.location,
                            let thumbMPH = firstPose.keypoints[.thumbMP]?.location,
                            let thumbIPH = firstPose.keypoints[.thumbIP]?.location,
                            
                                let indexMCPH = firstPose.keypoints[.indexMCP]?.location,
                            let indexPIPH = firstPose.keypoints[.indexPIP]?.location,
                            let indexDIPH = firstPose.keypoints[.indexDIP]?.location,
                            let indexTipH = firstPose.keypoints[.indexTip]?.location,
                            
                                let middleMCPH = firstPose.keypoints[.middleMCP]?.location,
                            let middlePIPH = firstPose.keypoints[.middlePIP]?.location,
                            let middleDIPH = firstPose.keypoints[.middleDIP]?.location,
                            let middleTipH = firstPose.keypoints[.middleTip]?.location,
                            
                                let ringMCPH = firstPose.keypoints[.ringMCP]?.location,
                            let ringPIPH = firstPose.keypoints[.ringPIP]?.location,
                            let ringDIPH = firstPose.keypoints[.ringDIP]?.location,
                            let ringTipH = firstPose.keypoints[.ringTip]?.location,
                            
                                let littleMCPH = firstPose.keypoints[.littleMCP]?.location,
                            let littlePIPH = firstPose.keypoints[.littlePIP]?.location,
                            let littleDIPH = firstPose.keypoints[.littleDIP]?.location,
                            let littleTipH = firstPose.keypoints[.littleTip]?.location
                        else {
                            return // exit early if any keypoint is missing
                        }
                        
                        let keypoints: [CGPoint] = [thumbTipLocationH, thumbCMCH, thumbMPH, thumbIPH, indexMCPH, indexPIPH, indexDIPH, indexTipH, middleMCPH, middlePIPH, middleDIPH, middleTipH, ringMCPH, ringPIPH, ringDIPH, ringTipH, littleMCPH, littlePIPH, littleDIPH, littleTipH]
                        var distances: [CGFloat] = []
                        var goalDistances: [CGFloat] = [0.3674964083942645, 0.3297043488014071, 0.20286794308110076, 0.2077588668689161, 0.25824981895237614, 0.30148754459582483, 0.33541352794244517, 0.0829670519481649, 0.13654593662607237, 0.19017882113774703, 0.22533274892691774, 0.046499086829793125, 0.07372137108613544, 0.15272970824806506, 0.23358323451637827, 0.17414396397869739, 0.1059387749792944, 0.07471760705036068, 0.1427524623000786, 0.12422927188930367, 0.22638468014256083, 0.26722315918921025, 0.3695647160403826, 0.4354415799923771, 0.4882775829329019, 0.3123753345380024, 0.4042590368189559, 0.4643724222216209, 0.513204286342453, 0.3594240503985497, 0.4411709241557989, 0.5191102399934527, 0.5992402883651324, 0.42571329018211673, 0.4264343274280729, 0.3310803404141493, 0.2512728751756432, 0.14063647153259418, 0.1696451530865228, 0.2583127025311832, 0.32121468380963036, 0.3734055078456325, 0.2559575083313707, 0.32488209915555033, 0.37760503036468085, 0.42549757467568305, 0.33773382439604854, 0.4006795151815278, 0.47021734631101697, 0.54614647674048, 0.4365853572512628, 0.41329746132028156, 0.3188806671291939, 0.2570330306375901, 0.045147555520392846, 0.154941963518669, 0.22226852528892782, 0.27428248430120317, 0.12212651221244991, 0.1849753746348555, 0.24074183624376735, 0.289365584770113, 0.2227279641627355, 0.2688416307561215, 0.3332119315926742, 0.40725191850377557, 0.342151737814535, 0.2994915306076294, 0.21455670062159948, 0.1840281669263528, 0.1098159134327822, 0.1771217841090107, 0.2291648396749028, 0.12490181425895411, 0.1590519858078733, 0.20820543743127834, 0.25588925291372194, 0.23573757004535117, 0.2662022947865545, 0.3223634728792682, 0.3919847853320276, 0.3620406092976627, 0.3105431978617907, 0.23406833794208584, 0.2172761236674889, 0.06743524289450314, 0.11996393200998084, 0.1877681831657181, 0.1475041785888776, 0.16156750072656884, 0.19897854848400523, 0.2980656143424696, 0.29425789425214366, 0.3258843562546528, 0.37951175660660225, 0.42973385876779246, 0.3636118044875642, 0.3077332453650591, 0.3126360627241396, 0.05288136451901318, 0.24072284804879726, 0.17323791238891265, 0.16056797640584736, 0.18350406671437036, 0.34476148952210667, 0.3245403753306248, 0.3407967370649461, 0.382159447210461, 0.47554068478669353, 0.4036801200021092, 0.3591331385856406, 0.3731526903327376, 0.2823478720854449, 0.20092640520850263, 0.17115148476326655, 0.18008159103885762, 0.38038322490767607, 0.3488546937941589, 0.35342443740610446, 0.38440492668077114, 0.5091229546523398, 0.43370914030927094, 0.3979523426662168, 0.41865716551055165, 0.10794295600796452, 0.17267024723420732, 0.21845836465024498, 0.11345991790491677, 0.14675829024069698, 0.21438619866038827, 0.2915909009733452, 0.2439027301754408, 0.18622080273765074, 0.11996507042967133, 0.14083915338459047, 0.06481461582064786, 0.11184541938684099, 0.18270482178652978, 0.15136868907450104, 0.17893724096190217, 0.2386496324910456, 0.30881878808902774, 0.23281249547360536, 0.20518941167590288, 0.2465803564006499, 0.04883221319282233, 0.236539088971692, 0.18367679642671808, 0.1825571312682667, 0.22224333269779284, 0.35525634665225003, 0.27482339895889063, 0.2628449734639246, 0.3101793219222236, 0.2706296816821165, 0.20447796784752856, 0.18298890057253556, 0.20447340206553, 0.381262543511952, 0.29885139607042793, 0.29969230066131475, 0.35311336950372035, 0.09458528158479175, 0.17541595892397638, 0.25521951400170967, 0.13167788383467605, 0.07696716056439915, 0.03534675394000905, 0.11687149365823665, 0.08135158256028874, 0.16198668030084384, 0.17773087827187042, 0.09479027286347096, 0.12992666287676188, 0.2095769799490408, 0.08091484932945449, 0.2338812936679807, 0.15507024904561864, 0.210638784233303, 0.2909275213548253, 0.2963884125374847, 0.224731815002306, 0.29019392153825946, 0.3713734374734241, 0.08301813012335345, 0.1281457680393456, 0.18070651890832, 0.09628326420774405, 0.17594841043401735, 0.08359715323578173]

                        for i in 0..<keypoints.count {
                            for j in i+1..<keypoints.count {
                                distances.append(distance(from: keypoints[i], to: keypoints[j]))
                            }
                        }
                        if (passesThresholdTest(average: findDistanceSimilarity(distances: distances, goalDistances: goalDistances), threshold: 0.045)) {
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
