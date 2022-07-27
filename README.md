# Counting human body action repetitions in a live video feed

Use Create ML Components to analyze a series of video frames and count a person's repetitive or periodic body movements.

## Overview

- Note: This sample code project is associated with WWDC22 session [110332: What's new in Create ML](https://developer.apple.com/wwdc22/110332/).

This sample app counts a person's repetitive or periodic body movements (*actions*)
by analyzing a series of video frames and making a prediction with a human body action repetition counter.
The counter in this sample can count arbitrary body moves that occur at moderate speed,
such as jumping jacks, dance spins, and waving arms.

![A flow diagram that illustrates two people performing jumping jacks in front of a device’s camera. A video reader extracts video frames from the camera, and then the pose extractor consumes the frames to generate poses of body location data. The Create ML Components framework consumes the pose data and predicts the count for the jumping jacks.][Overview-Diagram-1]

The app continually presents the current action repetition count on top of a
live, full-screen video feed from the camera in portrait orientation.
When the app detects one or more people in the frame, it overlays a wireframe body
pose on each person.
At the same time, the app predicts the action repetition count about the most prominent person across multiple frames, typically whoever is closest to the camera.

The app begins by configuring a camera to generate video frames, then directs the
frames through a series of transformers it chains together with Create ML Components.
These methods work together to:
1. Read camera frames in real time using [`VideoReader`][VideoReader].
2. Analyze each frame to locate any human body poses using [`HumanBodyPoseExtractor`][HumanBodyPoseExtractor], and redirect the pose stream with an [AsyncChannel](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md) to allow multiple consumers.
3. Optionally, downsample the stream using a [`Downsampler`][Downsampler] to process the observed actions in different speeds. To improve performance, you can move the downsampler to an earlier stage in the pipeline if you don't need to render poses on every frame.
4. Isolate the prominent pose using [`PoseSelector`][PoseSelector].
5. Optionally, use [`JointsSelector`][JointsSelector] to select only joints of interest for counting.
6. Aggregate the prominent pose's position data over time using [`SlidingWindowTransformer`][SlidingWindowTransformer].
7. Predict action repetitions by sending aggregate data to the [`HumanBodyActionCounter`][HumanBodyActionCounter].

## Configure the sample code project

This sample code project requires a device with iOS 16 or later, or iPadOS 16 or later.

To build this project:
1. Double-click the `CountMyActions.xcodeproj` project to open it in Xcode.
2. In Xcode, from the Project navigator, select the `CountMyActions` project and click the Signing & Capabilities tab.
3. Select your development team from the Add Account pop-up menu.
4. Select your target device from the scheme menu, and choose Product > Run.

## Start a live video feed

The app uses
[`VideoReader`][VideoReader]
to configure the device's camera and generate an asynchronous video frame sequence. The [`VideoReader.CameraConfiguration`][VideoReader.CameraConfiguration]
specifies the front- or rear-facing camera, and configures its pixel format and resolution.
This app supports portrait orientation only. Low lighting and other factors can vary the frame rate, which may affect the counting performance, so ensure the person's full body is visible in bright environments.

``` swift
/// The camera configuration to define the basic camera position, pixel format, and resolution to use.
private var configuration = VideoReader.CameraConfiguration()
```

When the app first launches — or when the user toggles the camera — 
the video reader configures a camera device, starts the video-processing pipeline, and produces a frame sequence output with [`VideoReader.readCamera(configuration:)`][VideoReader.readCamera(configuration:)].

``` swift
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
```

## Analyze each frame for body poses

The [`HumanBodyPoseExtractor`][HumanBodyPoseExtractor] is a transformer that can 
locate any human body poses from an image or a video frame.

``` swift
/// A Create ML Components transformer to extract human body poses from a single image or a video frame.
/// - Tag: poseExtractor
private let poseExtractor = HumanBodyPoseExtractor()
```

When the transformation completes, the method creates and returns a
[`Pose`][Pose]
array that contains one pose for every detected person in the same frame.

``` swift
// Extract poses in every frame.
let poses = try await poseExtractor.applied(to: frame.feature)
```

The
[`Pose`](x-source-tag://Pose)
structure serves the following purposes:
* Calculates the pose's area within a frame (See the "Isolate a body pose" section below.).
* Draws each detected pose as a wireframe of points and lines (See the "Present the poses to the user" section below.).

For more information about the underlying human body pose model,
see [Detecting Human Body Poses in Images].


## Create a pose stream

[AsyncChannel](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md) sends the extracted poses to a separate asynchronous stream. This allows additional consumers to obtain poses from the upstream asynchronous sequence. [AsyncChannel](https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md) requires the inclusion of the [AsyncAlgorithms](https://github.com/apple/swift-async-algorithms) Swift package.

``` swift
/// An asynchronous channel to divert the pose stream for another consumer.
private let poseStream = AsyncChannel<TemporalFeature<[Pose]>>()
```


## Create an action repetition counting pipeline
The [`ActionCounter`](x-source-tag://ActionCounter)
structure consists of a pipeline of Create ML Components transformers to achieve continuous action repetition counting.
It takes a pose stream as input and returns an asynchronous sequence of cumulative counts.

``` swift
/// The counter to count action repetitions from a pose stream.
private let actionCounter = ActionCounter()
```

## Downsample a pose stream

The first optional transformer in the pipeline, [`Downsampler`][Downsampler], downsamples the incoming pose sequence by an integer factor. This allows the pipeline to process and count much slower actions. For example, without downsampling, the original counter model can handle moderate speed actions, about one repetition per second, such as jumping jacks. A downsampling factor of three can effectively speed up slower actions, such as pushups or a complex dance sequence with about one repetition per 3 seconds, and still allow the model to count the actions.

``` swift
// Use an optional Downsampler transformer to downsample the
// incoming frames (that is, effectively speed up the observed actions).
let pipeline = Downsampler(factor: 1)
```

## Isolate a body pose

The next transformer in the pipeline, [`PoseSelector`][PoseSelector], selects a single pose from the array of
poses by using the default strategy, namely, selecting the most prominent person by their maximum bounding box area.

``` swift
// Use a PoseSelector transformer to select one pose to count if
// the system detects multiple poses.
    .appending(PoseSelector(strategy: .maximumBoundingBoxArea))
```

The goal of this strategy is to consistently select the same person's pose from a crowd over time. 

![A flow diagram that illustrates two detected poses in the same frame passing into a pose selector, where the default strategy selects the most-prominent pose, and the output is a single pose.
][PoseSelector-Diagram]

- Important: Get the most accurate predictions by using whatever
strategy best tracks a person from frame to frame.


## Select a subset of body joints

The next optional transformer in the pipeline, [`JointsSelector`][JointsSelector], selects or ignores a specified subset of body joints from the pose. 

![A flow diagram that illustrates a full body pose passing into a joints selector, which reduces it to a subset of joints that consists of an upper-body-only pose.
][JointsSelector-Diagram]

For example, to count only upper-body movements, the transformer can ignore lower-body joints in the pose, such as knees and ankles, which can eliminate noise by ignoring any leg movements.

``` swift
// Use an optional JointsSelector transformer to specifically ignore
// or select a set of joints in a pose to include in counting.
    .appending(JointsSelector(ignoredJoints: [.nose, .leftEye, .leftEar, .rightEye, .rightEar]))
```

## Gather a window of poses

The next transformer in the pipeline is a
[`SlidingWindowTransformer`][SlidingWindowTransformer]
that receives a pose sequence from its upstream and gathers the frames into an array
by providing the following parameters:

* A `stride` that determines the number of frames to count before updating the pose window
* A `length` that determines the window size, namely, how many frames to group together

``` swift
// Use a SlidingWindowTransformer to group frames into windows, and
// prepare them for prediction.
    .appending(SlidingWindowTransformer<Pose>(stride: 5, length: 90))
```

![A flow diagram that illustrates a pose sequence passing into a sliding window transformer, which defines the stride and length for its window.
][SlidingWindowTransformer-Diagram]

The action repetition counter assumes a fixed length of 90, where the sliding window transformer groups 90 frames together to generate a single prediction count. The stride is adjustable. An example is a stride of 10 frames, indicating the count updates every 10 frames, which is about 0.3 seconds if the frame rate is 30 frames per second. When the stride is smaller than the length, the windows overlap.

## Predict the person's action repetition count

The next transformer in the pipeline, [`HumanBodyActionCounter`][HumanBodyActionCounter], takes a stream of grouped pose windows as input and produces a [`HumanBodyActionCounter.CumulativeSumSequence`][HumanBodyActionCounter.CumulativeSumSequence] where each result is a cumulative count of the actions in the sequence. Live counting occurs by iterating each item in the resulted sequence.

``` swift
// Use a HumanBodyActionCounter transformer to count actions from
// each window and produce cumulative counts for the input stream.
    .appending(HumanBodyActionCounter())
```

## Present the count to the user

The final count appears as a [SwiftUI] label on the screen using the
[`OverlayView`](x-source-tag://OverlayView)
structure on the main thread.


## Present the poses to the user

The app visualizes the result of each detected human body pose by drawing the poses on top
of the frame that 
[`HumanBodyPoseExtractor`][HumanBodyPoseExtractor]
finds them in.
Each time the 
[`poseExtractor`](x-source-tag://poseExtractor)
creates an array of
[`Pose`][Pose]
instances, the [`PosesView`](x-source-tag://PosesView)
iterates each detected pose and draws it by calling its
[`drawWireframe(to:applying:)`](x-source-tag://drawWireframe)
method, which draws the pose as a wireframe of connection lines and joint circles.

``` swift
// Draw all the poses Vision finds in the frame.
for pose in poses {
    // Draw each pose as a wireframe at the scale of the image.
    pose.drawWireframe(to: context, applying: pointTransform)
}
```

 The [`ViewModel`](x-source-tag://ViewModel)
 presents the image and poses onscreen by calling [`display(image:, poses:)`](x-source-tag://display)
 method.

[--- Images + Diagrams ---]: <>
[Overview-Diagram-1]: Documentation/@2xcreateml-components-framework-overview.png
[PoseSelector-Diagram]: Documentation/@2xpose-selector.png
[JointsSelector-Diagram]: Documentation/@2xjoints-selector.png
[SlidingWindowTransformer-Diagram]: Documentation/@2xsliding-window.png

[--- Frameworks ---]: <> (Framework landing pages)
[Create ML Components]: https://developer.apple.com/documentation/createmlcomponents
[SwiftUI]: https://developer.apple.com/documentation/swiftui

[--- Packages ---]: <>
[AsyncAlgorithms]: https://github.com/apple/swift-async-algorithms

[--- Types ---]: <>
[CGImage]: https://developer.apple.com/documentation/coregraphics/cgimage
[VideoReader]: https://developer.apple.com/documentation/createmlcomponents/videoreader
[HumanBodyPoseExtractor]: https://developer.apple.com/documentation/createmlcomponents/humanbodyposeextractor
[AsyncChannel]: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md
[Downsampler]: https://developer.apple.com/documentation/createmlcomponents/downsampler
[PoseSelector]: https://developer.apple.com/documentation/createmlcomponents/poseselector
[JointsSelector]: https://developer.apple.com/documentation/createmlcomponents/jointsselector
[SlidingWindowTransformer]: https://developer.apple.com/documentation/createmlcomponents/slidingwindowtransformer
[HumanBodyActionCounter]: https://developer.apple.com/documentation/createmlcomponents/humanbodyactioncounter
[VideoReader.CameraConfiguration]: https://developer.apple.com/documentation/createmlcomponents/videoreader/cameraconfiguration
[Pose]: https://developer.apple.com/documentation/createmlcomponents/pose
[HumanBodyActionCounter.CumulativeSumSequence]: https://developer.apple.com/documentation/createmlcomponents/humanbodyactioncounter/cumulativesumsequence

[--- Methods ---]: <>
[AsyncChannel.send(_:)]: https://github.com/apple/swift-async-algorithms/blob/main/Sources/AsyncAlgorithms/AsyncAlgorithms.docc/Guides/Channel.md
[VideoReader.readCamera(configuration:)]: https://developer.apple.com/documentation/createmlcomponents/videoreader/readcamera(configuration:)

[--- Articles ---]: <>
[Detecting Human Body Poses in Images]: https://developer.apple.com/documentation/vision/detecting_human_body_poses_in_images
