//
//  DepthDataProcessingHelper.swift
//  ar_flutter_plugin
//
//  Created by Kusyumov Nikita on 12.10.2022.
//

import ARKit
import AVFoundation

class DepthDataProcessingHelper: NSObject {

    // MARK: - Private properties
    
    private let captureSession = AVCaptureSession()
    private var depthMap: CIImage?
    private let dataOutputQueue = DispatchQueue(label: "video data queue",
                                        qos: .userInitiated,
                                        attributes: [],
                                        autoreleaseFrequency: .workItem)
    
    // MARK: - External properties
    
    lazy var depthCoverImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        return imageView
    }()
    
    // MARK: - opened functions
    
    /// Configure AVSession and setup delegates
    func configureCaptureSession() {
        guard let camera = AVCaptureDevice.default(.builtInDualCamera, for: .video, position: .unspecified) else {
            fatalError("No depth video camera available")
        }

        captureSession.sessionPreset = .photo

        do {
            if captureSession.inputs.isEmpty {
                let cameraInput = try AVCaptureDeviceInput(device: camera)
                captureSession.addInput(cameraInput)
            }
        } catch {
            fatalError(error.localizedDescription)
        }

        let videoOutput = AVCaptureVideoDataOutput()
        videoOutput.setSampleBufferDelegate(self, queue: dataOutputQueue)
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        
        if captureSession.outputs.isEmpty {
            captureSession.addOutput(videoOutput)
        }

        let videoConnection = videoOutput.connection(with: .video)
        videoConnection?.videoOrientation = .portrait

        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.setDelegate(self, callbackQueue: dataOutputQueue)
        depthOutput.isFilteringEnabled = true
        captureSession.addOutput(depthOutput)

        let depthConnection = depthOutput.connection(with: .depthData)
        depthConnection?.videoOrientation = .portrait

        do {
            try camera.lockForConfiguration()

            if let format = camera.activeDepthDataFormat,
               let range = format.videoSupportedFrameRateRanges.first  {
                camera.activeVideoMinFrameDuration = range.minFrameDuration
            }

            camera.unlockForConfiguration()
        } catch {
            fatalError(error.localizedDescription)
        }
        captureSession.startRunning()
    }
    
    /// Method get depthData from LiDAR Senssor and colored overlay view with depth image
    /// https://developer.apple.com/documentation/arkit/environmental_analysis/creating_a_fog_effect_using_scene_depth
    /// Use this link for make updates for iPhones with Lidar test
    func colorDepth(frame: ARFrame, sceneView: ARSCNView) {
        if #available(iOS 14.0, *) {
            guard let depthData = frame.smoothedSceneDepth else {
                print("ERRPR: Can't extract depth data from frame")
                return
            }
            let pixelBuffer = depthData.depthMap
            let ciImage = CIImage(cvImageBuffer: pixelBuffer)
            
            DispatchQueue.main.async {
                self.depthCoverImageView.image = UIImage(ciImage: ciImage)
            }
        } else {
            // Not nessesary checked on higher level
        }
    }
    
    /// Stop session and delete inputs and outputs from session
    func stopSession() {
        if captureSession.isRunning {
            DispatchQueue.global().async {
                self.captureSession.stopRunning()
            }
            /// Remove inputs
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            /// Remove outputs
            for output in captureSession.outputs {
                captureSession.removeOutput(output)
            }
        }
    }
    
}

// MARK: - Capture Video Data Delegate Methods

extension DepthDataProcessingHelper: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)
        let image = CIImage(cvPixelBuffer: pixelBuffer!)

        let previewImage: CIImage = depthMap ?? image

        let displayImage = UIImage(ciImage: previewImage)
        DispatchQueue.main.async { [weak self] in
            self?.depthCoverImageView.image = displayImage
        }
    }
    
}

// MARK: - Capture Depth Data Delegate Methods

extension DepthDataProcessingHelper: AVCaptureDepthDataOutputDelegate {
    
    func depthDataOutput(_ output: AVCaptureDepthDataOutput, didOutput depthData: AVDepthData, timestamp: CMTime, connection: AVCaptureConnection) {
        var convertedDepth: AVDepthData

        let depthDataType = kCVPixelFormatType_DisparityFloat32
        if depthData.depthDataType != depthDataType {
            convertedDepth = depthData.converting(toDepthDataType: depthDataType)
        } else {
            convertedDepth = depthData
        }
        
        let pixelBuffer = convertedDepth.depthDataMap
        pixelBuffer.clamp()

        let depthMap = CIImage(cvPixelBuffer: pixelBuffer)

        DispatchQueue.main.async { [weak self] in
            self?.depthMap = depthMap
        }
    }
    
}

// MARK: - Extension of CVPixelBuffer for Depth calculations

extension CVPixelBuffer {
    
    func clamp() {
        let width = CVPixelBufferGetWidth(self)
        let height = CVPixelBufferGetHeight(self)
    
        CVPixelBufferLockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
        let floatBuffer = unsafeBitCast(CVPixelBufferGetBaseAddress(self), to: UnsafeMutablePointer<Float>.self)

        /// You might be wondering why the for loops below use `stride(from:to:step:)`
        /// instead of a simple `Range` such as `0 ..< height`?
        /// The answer is because in Swift 5.1, the iteration of ranges performs badly when the
        /// compiler optimisation level (`SWIFT_OPTIMIZATION_LEVEL`) is set to `-Onone`,
        /// which is eactly what happens when running this sample project in Debug mode.
        /// If this was a production app then it might not be worth worrying about but it is still
        /// worth being aware of.

        for y in stride(from: 0, to: height, by: 1) {
            for x in stride(from: 0, to: width, by: 1) {
                let pixel = floatBuffer[y * width + x]
                floatBuffer[y * width + x] = min(1.0, max(pixel, 0.0))
            }
        }
    
        CVPixelBufferUnlockBaseAddress(self, CVPixelBufferLockFlags(rawValue: 0))
    }
    
}
