//
//  CameraViewController.swift
//  SocialDistancer_v7
//
//

import UIKit
import AVFoundation
import Photos
import CoreVideo
import MobileCoreServices
import Accelerate
import CoreMotion
import RealityKit
import ARKit

class DataViewController : UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    var pickerData: [String] = []
    static var chosenFeet = "0"
    static var chosenInches = "0"
    static var chosenRow = 67
    static let shoulderBodyProportion = 0.82
    static var useHumanHeight = true
    let heightLabel = UILabel()
    
    @IBOutlet weak var segmentedControlButton: UISegmentedControl!
    
    @IBAction func changeSegmentedControl(_ sender: UISegmentedControl) {
        switch segmentedControlButton.selectedSegmentIndex {
            case 0:
                DataViewController.useHumanHeight = true
            case 1:
                DataViewController.useHumanHeight = false
            default:
                DataViewController.useHumanHeight = true
        }
    }
    
    @IBOutlet weak var heightPicker: UIPickerView!
    @IBOutlet weak var heightStackView: UIStackView!
    
    @IBOutlet weak var goBack: UIButton!

    @IBOutlet weak var sayThisTextField: UITextField!
    static var sayThisText = "Oh no! Violating Social Distancing!"
    
    @IBAction func goBack(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
        textField.resignFirstResponder()
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.heightPicker.delegate = self
        self.heightPicker.dataSource = self
        self.sayThisTextField.delegate = self
        self.sayThisTextField.placeholder = DataViewController.sayThisText
        //pickerData = [["0", "1", "2", "3", "4", "5", "6", "7"], ["0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "10", "11"]]
        for feet in 0...7 {
            for inches in 0...11 {
                pickerData.append("\(feet)'\(inches)\"")
            }
        }
        if DataViewController.useHumanHeight {
            segmentedControlButton.selectedSegmentIndex = 0
        } else {
            segmentedControlButton.selectedSegmentIndex = 1
        }
        print("DataViewController.chosenRow: \(DataViewController.chosenRow)")
        self.heightPicker.selectRow(DataViewController.chosenRow, inComponent: 0, animated: false)
        self.heightLabel.text = "Height:"
        
        self.heightPicker.setPickerLabels(labels: [0: self.heightLabel], containedView: heightStackView)
    }
    
    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerData.count
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        DataViewController.chosenRow = row
        print("New DataViewController.chosenRow: \(DataViewController.chosenRow)")
        let val = pickerData[row]
        print("row:\(row) val:\(val)")
        let valArr = val.components(separatedBy: "'")
        DataViewController.chosenFeet = valArr[0]
        DataViewController.chosenInches = String(valArr[1].dropLast())
        print("feet: \(DataViewController.chosenFeet)")
        print("inches: \(DataViewController.chosenInches)")
    }
 
    func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
    return 1.0
}
    
    func getHeight() -> Int {
        //print("calculating height")
        //print(DataViewController.chosenFeet)
        //print((Int(DataViewController.chosenFeet) ?? 0) * 12)
        var height = (Int(DataViewController.chosenFeet) ?? 0) * 12 + (Int(DataViewController.chosenInches) ?? 0)
        if (DataViewController.useHumanHeight) {
            height = Int(Double(height) * DataViewController.shoulderBodyProportion)
        }
        return height
    }
}

extension UIPickerView {
   
    func setPickerLabels(labels: [Int:UILabel], containedView: UIView) { // [component number:label]
        
        let fontSize:CGFloat = 20
        let labelWidth:CGFloat = containedView.bounds.width / CGFloat(self.numberOfComponents)
        let x:CGFloat = self.frame.origin.x
        let y:CGFloat = (self.frame.size.height / 2) - (fontSize / 2)
        
        for i in 0...self.numberOfComponents {
            if let label = labels[i] {
                if self.subviews.contains(label) {
                    label.removeFromSuperview()
                }
                
                label.frame = CGRect(x: x + labelWidth * CGFloat(i), y: y, width: labelWidth, height: fontSize)
                label.font = UIFont.boldSystemFont(ofSize: fontSize)
                label.backgroundColor = .clear
                label.textAlignment = NSTextAlignment.left
                
                self.addSubview(label)
            }
        }
    }
}

class CameraViewController: UIViewController, ItemSelectionViewControllerDelegate, ARSessionDelegate {


    @IBOutlet weak var arView: ARView!
    
    let dataViewController = DataViewController()
    
    let synthesizer = AVSpeechSynthesizer()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    private var spinner: UIActivityIndicatorView!
    
    var motionManager = CMMotionManager()
    
    private var outputSynchronizer: AVCaptureDataOutputSynchronizer?
    
    var windowOrientation: UIInterfaceOrientation {
        return view.window?.windowScene?.interfaceOrientation ?? .unknown
    }
    
    
    @IBOutlet weak var distanceMethodSegmentedControl: UISegmentedControl!
    
    var useARDistanceMethod = true
    

    @IBAction func distanceMethodSegmentedControlUpdate(_ sender: Any) {
        print("here")
        switch distanceMethodSegmentedControl.selectedSegmentIndex {
            case 0:
                self.useARDistanceMethod = true
                print("switch to AR")
            case 1:
                self.useARDistanceMethod = false
                print("switch to tilt")
            default:
                self.useARDistanceMethod = true
        }
    }
    
    var yellingEnabled = false
    @IBAction func pressEnableYelling(_ sender: Any) {
        self.yellingEnabled = true
        
    }
    
    @IBAction func releaseEnableYelling(_ sender: Any) {
        self.yellingEnabled = false
        self.synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }
    
    let safeDistance = 6 * 12
    private var distanceString = "Distance: ???"
    private var distance = 99999.0
    private var pitch = 0.0 {
        didSet {
            self.updateDistance()
        }
    }
    private var ARDistance = 99999.0 {
        didSet {
            self.updateDistance()
        }
    }
    
    func updateDistance() {
        if self.useARDistanceMethod {
            self.distance = self.ARDistance
            //print("updated distance b/c AR")
        } else {
            self.distance = tan(pitch) * Double(self.dataViewController.getHeight())
            //print("updated distance b/c tilt")
        }
        self.distanceString = "Distance: \(Int(self.distance/12))'\(Int(self.distance)%12)\""
        //print(self.distanceString)
        DispatchQueue.main.async {
            self.distanceDisplay.text = self.distanceString
        }
        if (Int(self.distance) <= self.safeDistance) {
            DispatchQueue.main.async {
                self.distanceDisplay.backgroundColor = UIColor.red
            }
            if (!self.synthesizer.isSpeaking) && (self.yellingEnabled) {
                self.yell()
            }
        }  else if (Int(self.distance) > self.safeDistance) {
            DispatchQueue.main.async {
                self.distanceDisplay.backgroundColor = UIColor.black
            }
        }
    }
    
    @IBOutlet weak var distanceDisplay: UILabel!
    
    // MARK: View Controller Life Cycle
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.arView.session.delegate = self
        guard ARBodyTrackingConfiguration.isSupported else {
            fatalError("This feature is only supported on devices with an A12 chip")
        }


        // Run a body tracking configration.
        let configuration = ARBodyTrackingConfiguration()
        arView.session.run(configuration)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("uh oh, audio went wrong")
        }
        
        // Ensure to keep a strong reference to the motion manager otherwise you won't get updates
        
        print(motionManager.isDeviceMotionAvailable)
        motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical)
        if motionManager.isDeviceMotionAvailable == true {

            motionManager.deviceMotionUpdateInterval = 0.1;

            let queue = OperationQueue()
            motionManager.startDeviceMotionUpdates(using: .xMagneticNorthZVertical,
               to: queue, withHandler: { (data, error) in
                 // Make sure the data is valid before accessing it.
                 if let validData = data {
                    // Get the attitude relative to the magnetic north reference frame.
                    self.pitch = validData.attitude.pitch
                 }
            })
            print("Device motion started")
        }
        else {
            print("Device motion unavailable");
        }
        
        // Disable the UI. Enable the UI later, if and only if the session starts running.
        
        // Set up the video preview view.
        //previewView.session = session
        /*
         Check the video authorization status. Video access is required and audio
         access is optional. If the user denies audio access, AVCam won't
         record audio during movie recording.
         */
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // The user has previously granted access to the camera.
            break
            
        case .notDetermined:
            /*
             The user has not yet been presented with the option to grant
             video access. Suspend the session queue to delay session
             setup until the access request has completed.
             
             Note that audio access will be implicitly requested when we
             create an AVCaptureDeviceInput for audio during session setup.
             */
            sessionQueue.suspend()
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                if !granted {
                    self.setupResult = .notAuthorized
                }
                self.sessionQueue.resume()
            })
            
        default:
            // The user has previously denied access.
            setupResult = .notAuthorized
        }
        
        /*
         Setup the capture session.
         In general, it's not safe to mutate an AVCaptureSession or any of its
         inputs, outputs, or connections from multiple threads at the same time.
         
         Don't perform these tasks on the main queue because
         AVCaptureSession.startRunning() is a blocking call, which can
         take a long time. Dispatch session setup to the sessionQueue, so
         that the main queue isn't blocked, which keeps the UI responsive.
         */
        DispatchQueue.main.async {
            self.spinner = UIActivityIndicatorView(style: .large)
            self.spinner.color = UIColor.yellow
            self.arView.addSubview(self.spinner)
        }
        DispatchQueue.main.async{
            self.distanceDisplay.text = self.distanceString
        }
        print("finished viewdidload")
    }
        
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        var minDistance = 100000.0
        for anchor in anchors {
            print("anchor")
            guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
            //guard let sceneView = self.arView as? ARSKView else {
            //   return
            //}
            print("here")
            // Update the position of the character anchor's position.
            //let bodyPosition = simd_make_float3(bodyAnchor.transform.columns.3)
            //let anchorPosition = anchor.transform.columns.3
            //let cameraPosition = sceneView.session.currentFrame?.camera.transform.columns.3
            //let cameraToAnchor = cameraPosition - anchorPosition
            //let distance = length(cameraToAnchor)
            let distance = Double(simd_distance(bodyAnchor.transform.columns.3, (arView.session.currentFrame?.camera.transform.columns.3)!))
            if distance < minDistance {
                minDistance = distance
            }
            // Also copy over the rotation of the body anchor, because the skeleton's pose
            // in the world is relative to the body anchor's rotation.
        }
        self.ARDistance = minDistance
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                // Only setup observers and start the session if setup succeeded.
                self.addObservers()
                self.captureSession.startRunning()
                self.isSessionRunning = self.captureSession.isRunning
                
            case .notAuthorized:
                DispatchQueue.main.async {
                    let changePrivacySetting = "AVCam doesn't have permission to use the camera, please change privacy settings"
                    let message = NSLocalizedString(changePrivacySetting, comment: "Alert message when the user has denied access to the camera")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("Settings", comment: "Alert button to open Settings"),
                                                            style: .`default`,
                                                            handler: { _ in
                                                                UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!,
                                                                                          options: [:],
                                                                                          completionHandler: nil)
                    }))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
                
            case .configurationFailed:
                DispatchQueue.main.async {
                    let alertMsg = "Alert message when something goes wrong during capture session configuration"
                    let message = NSLocalizedString("Unable to capture media", comment: alertMsg)
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    
                    alertController.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"),
                                                            style: .cancel,
                                                            handler: nil))
                    
                    self.present(alertController, animated: true, completion: nil)
                }
            }
        }
        print("finished viewwillappear")
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        sessionQueue.async {
            if self.setupResult == .success {
                self.captureSession.stopRunning()
                self.isSessionRunning = self.captureSession.isRunning
                self.removeObservers()
            }
        }
        
        super.viewWillDisappear(animated)
    }

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    private let captureSession = AVCaptureSession()
    private var isSessionRunning = false
    private var selectedSemanticSegmentationMatteTypes = [AVSemanticSegmentationMatte.MatteType]()
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    @IBOutlet private weak var previewView: PreviewView!
    
    
    func yell() {
        let utterance = AVSpeechUtterance(string: DataViewController.sayThisText)
        print("Yelling: \(DataViewController.sayThisText)")
        //utterance.voice = AVSpeechSynthesisVoice(identifier: "com.apple.ttsbundle.Fred-compact")
        //print(utterance.voice)
        //utterance.voice = AVSpeechSynthesisVoice(language: "en-GB")
        self.synthesizer.speak(utterance)
    }
    
    @IBAction private func resumeInterruptedSession(_ resumeButton: UIButton) {
        sessionQueue.async {
            /*
             The session might fail to start running, for example, if a phone or FaceTime call is still
             using audio or video. This failure is communicated by the session posting a
             runtime error notification. To avoid repeatedly failing to start the session,
             only try to restart the session in the error handler if you aren't
             trying to resume the session.
             */
            print("resuming")
            self.captureSession.startRunning()
            self.isSessionRunning = self.captureSession.isRunning
            if !self.captureSession.isRunning {
                DispatchQueue.main.async {
                    let message = NSLocalizedString("Unable to resume", comment: "Alert message when unable to resume the session running")
                    let alertController = UIAlertController(title: "AVCam", message: message, preferredStyle: .alert)
                    let cancelAction = UIAlertAction(title: NSLocalizedString("OK", comment: "Alert OK button"), style: .cancel, handler: nil)
                    alertController.addAction(cancelAction)
                    self.present(alertController, animated: true, completion: nil)
                }
            } else {
            }
            print("finished resume")
        }
    }
    
    private enum CaptureMode: Int {
        case photo = 0
        case movie = 1
    }
    
    // MARK: Device Configuration
    
    
    @IBOutlet private weak var cameraUnavailableLabel: UILabel!
    
    private let videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
                                                                               mediaType: .video, position: .unspecified)
    
    private func focus(with focusMode: AVCaptureDevice.FocusMode,
                       exposureMode: AVCaptureDevice.ExposureMode,
                       at devicePoint: CGPoint,
                       monitorSubjectAreaChange: Bool) {
        
        sessionQueue.async {
            let device = self.videoDeviceInput.device
            do {
                try device.lockForConfiguration()
                
                /*
                 Setting (focus/exposure)PointOfInterest alone does not initiate a (focus/exposure) operation.
                 Call set(Focus/Exposure)Mode() to apply the new point of interest.
                 */
                if device.isFocusPointOfInterestSupported && device.isFocusModeSupported(focusMode) {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = focusMode
                }
                
                if device.isExposurePointOfInterestSupported && device.isExposureModeSupported(exposureMode) {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = exposureMode
                }
                
                device.isSubjectAreaChangeMonitoringEnabled = monitorSubjectAreaChange
                device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        }
    }
    
    private let photoOutput = AVCapturePhotoOutput()
    
    private enum DepthDataDeliveryMode {
        case on
        case off
    }

    private var depthDataDeliveryMode: DepthDataDeliveryMode = .off
        
    // MARK: ItemSelectionViewControllerDelegate
    
    let semanticSegmentationTypeItemSelectionIdentifier = "SemanticSegmentationTypes"
    
    private func presentItemSelectionViewController(_ itemSelectionViewController: ItemSelectionViewController) {
        let navigationController = UINavigationController(rootViewController: itemSelectionViewController)
        navigationController.navigationBar.barTintColor = .black
        navigationController.navigationBar.tintColor = view.tintColor
        present(navigationController, animated: true, completion: nil)
    }
    
    func itemSelectionViewController(_ itemSelectionViewController: ItemSelectionViewController,
                                     didFinishSelectingItems selectedItems: [AVSemanticSegmentationMatte.MatteType]) {
        let identifier = itemSelectionViewController.identifier
        
        if identifier == semanticSegmentationTypeItemSelectionIdentifier {
            sessionQueue.async {
                self.selectedSemanticSegmentationMatteTypes = selectedItems
            }
        }
    }
    
    private var inProgressLivePhotoCapturesCount = 0
    
    @IBOutlet var capturingLivePhotoLabel: UILabel!
    
    // MARK: Recording Movies
    
    // MARK: KVO and Notifications
    
    private var keyValueObservations = [NSKeyValueObservation]()
    /// - Tag: ObserveInterruption
    private func addObservers() {
        let keyValueObservation = captureSession.observe(\.isRunning, options: .new) { _, change in
            guard change.newValue != nil else { return }
        }
        keyValueObservations.append(keyValueObservation)
        
        let systemPressureStateObservation = observe(\.videoDeviceInput.device.systemPressureState, options: .new) { _, change in
            guard let systemPressureState = change.newValue else { return }
            self.setRecommendedFrameRateRangeForPressureState(systemPressureState: systemPressureState)
        }
        keyValueObservations.append(systemPressureStateObservation)
        /*
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(subjectAreaDidChange),
                                               name: .AVCaptureDeviceSubjectAreaDidChange,
                                               object: videoDeviceInput.device)
        
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionRuntimeError),
                                               name: .AVCaptureSessionRuntimeError,
                                               object: session)
        */
        /*
         A session can only run when the app is full screen. It will be interrupted
         in a multi-app layout, introduced in iOS 9, see also the documentation of
         AVCaptureSessionInterruptionReason. Add observers to handle these session
         interruptions and show a preview is paused message. See the documentation
         of AVCaptureSessionWasInterruptedNotification for other interruption reasons.
         */
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionWasInterrupted),
                                               name: .AVCaptureSessionWasInterrupted,
                                               object: session)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sessionInterruptionEnded),
                                               name: .AVCaptureSessionInterruptionEnded,
                                               object: session)
    }
    
    private func removeObservers() {
        NotificationCenter.default.removeObserver(self)
        
        for keyValueObservation in keyValueObservations {
            keyValueObservation.invalidate()
        }
        keyValueObservations.removeAll()
    }
    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
    }
    
    /// - Tag: HandleRuntimeError
    @objc
    func sessionRuntimeError(notification: NSNotification) {
        guard let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError else { return }
        
        print("Capture session runtime error: \(error)")
        // If media services were reset, and the last start succeeded, restart the session.
        if error.code == .mediaServicesWereReset {
            sessionQueue.async {
                if self.isSessionRunning {
                    self.captureSession.startRunning()
                    self.isSessionRunning = self.captureSession.isRunning
                }
            }
        }
    }
    
    /// - Tag: HandleSystemPressure
    private func setRecommendedFrameRateRangeForPressureState(systemPressureState: AVCaptureDevice.SystemPressureState) {
        /*
         The frame rates used here are only for demonstration purposes.
         Your frame rate throttling may be different depending on your app's camera configuration.
         */
        let pressureLevel = systemPressureState.level
        if pressureLevel == .serious || pressureLevel == .critical {
            do {
                try self.videoDeviceInput.device.lockForConfiguration()
                print("WARNING: Reached elevated system pressure level: \(pressureLevel). Throttling frame rate.")
                self.videoDeviceInput.device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 20)
                self.videoDeviceInput.device.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 15)
                self.videoDeviceInput.device.unlockForConfiguration()
            } catch {
                print("Could not lock device for configuration: \(error)")
            }
        } else if pressureLevel == .shutdown {
            print("Session stopped running due to shutdown system pressure level.")
        }
    }
    
    /// - Tag: HandleInterruption
    
    @objc
    private func sessionWasInterrupted(notification: NSNotification) {
        /*
         In some scenarios you want to enable the user to resume the session.
         For example, if music playback is initiated from Control Center while
         using AVCam, then the user can let AVCam resume
         the session running, which will stop music playback. Note that stopping
         music playback in Control Center will not automatically resume the session.
         Also note that it's not always possible to resume, see `resumeInterruptedSession(_:)`.
         */
         
        if let userInfoValue = notification.userInfo?[AVCaptureSessionInterruptionReasonKey] as AnyObject?,
            let reasonIntegerValue = userInfoValue.integerValue,
            let reason = AVCaptureSession.InterruptionReason(rawValue: reasonIntegerValue) {
            print("Capture session was interrupted with reason \(reason)")
            
            var showResumeButton = false
            if reason == .audioDeviceInUseByAnotherClient || reason == .videoDeviceInUseByAnotherClient {
                showResumeButton = true
            } else if reason == .videoDeviceNotAvailableWithMultipleForegroundApps {
                // Fade-in a label to inform the user that the camera is unavailable.
                cameraUnavailableLabel.alpha = 0
                cameraUnavailableLabel.isHidden = false
                UIView.animate(withDuration: 0.25) {
                    self.cameraUnavailableLabel.alpha = 1
                }
            } else if reason == .videoDeviceNotAvailableDueToSystemPressure {
                print("Session stopped running due to shutdown system pressure level.")
            }
        }
    }
    
    @objc
    private func sessionInterruptionEnded(notification: NSNotification) {
        print("Capture session interruption ended")
        
        if !cameraUnavailableLabel.isHidden {
            UIView.animate(withDuration: 0.25,
                           animations: {
                            self.cameraUnavailableLabel.alpha = 0
            }, completion: { _ in
                self.cameraUnavailableLabel.isHidden = true
            }
            )
        }
    }
}

extension AVCaptureVideoOrientation {
    init?(deviceOrientation: UIDeviceOrientation) {
        switch deviceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeRight
        case .landscapeRight: self = .landscapeLeft
        default: return nil
        }
    }
    
    init?(interfaceOrientation: UIInterfaceOrientation) {
        switch interfaceOrientation {
        case .portrait: self = .portrait
        case .portraitUpsideDown: self = .portraitUpsideDown
        case .landscapeLeft: self = .landscapeLeft
        case .landscapeRight: self = .landscapeRight
        default: return nil
        }
    }
}

extension AVCaptureDevice.DiscoverySession {
    var uniqueDevicePositionsCount: Int {
        
        var uniqueDevicePositions = [AVCaptureDevice.Position]()
        
        for device in devices where !uniqueDevicePositions.contains(device.position) {
            uniqueDevicePositions.append(device.position)
        }
        
        return uniqueDevicePositions.count
    }
}

