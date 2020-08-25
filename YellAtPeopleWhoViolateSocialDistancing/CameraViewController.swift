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

    var pickerData: [[String]] = [["Height:"], []]
    static var chosenFeet = "5"
    static var chosenInches = "7"
    static var chosenRow = 67
    static let shoulderBodyProportion = 0.82
    static var useHumanHeight = true

    
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
    static var sayThisText = "Social distancing is for your safety. I haven't showered in weeks."
    

    @IBAction func goBack(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func textFieldChanged(_ sender: UITextField) {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
        print(DataViewController.sayThisText)
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
                pickerData[1].append("\(feet)'\(inches)\"")
            }
        }
        if DataViewController.useHumanHeight {
            segmentedControlButton.selectedSegmentIndex = 0
        } else {
            segmentedControlButton.selectedSegmentIndex = 1
        }
        self.heightPicker.selectRow(DataViewController.chosenRow, inComponent: 1, animated: false)
    
    }
    

    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (component == 0) {
            return 1
        } else {
            return pickerData[1].count
        }
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        print(component)
        print(row)
        return pickerData[component][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        DataViewController.chosenRow = row
        print("New DataViewController.chosenRow: \(DataViewController.chosenRow)")
        let val = pickerData[component][row]
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

class CameraViewController: UIViewController, ARSessionDelegate {

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
    
    var ARSupported = true
    
    @IBOutlet weak var distanceMethodSegmentedControl: UISegmentedControl!
    
    var useARDistanceMethod = true

    @IBAction func distanceMethodSegmentedControlUpdate(_ sender: Any) {
        print("here")
        if self.ARSupported {
            switch distanceMethodSegmentedControl.selectedSegmentIndex {
                case 0:
                    self.useARDistanceMethod = true
                    print("switch to AR")
                case 1:
                    self.useARDistanceMethod = false
                    print("switch to trig")
                default:
                    self.useARDistanceMethod = true
            }
        } else {
            distanceMethodSegmentedControl.selectedSegmentIndex = 1
            self.useARDistanceMethod = false
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
    
    @IBAction func releaseEnableYellingDrag(_ sender: UIButton) {
        self.yellingEnabled = false
        self.synthesizer.stopSpeaking(at: AVSpeechBoundary.immediate)
    }
    
    let safeDistance = 6 * 12
    private var distanceString = "Distance: ???"
    private var distance = 99999.0
    private var lastDistance = 99999.0
    private var ARconsecutiveNonUpdates = 0
    private var lastARDistanceUpdateTime = CACurrentMediaTime() + 10
    private var pitch = 0.0 {
        didSet {
            self.updateDistance()
        }
    }
    private var ARDistance = 99999.0 {
        didSet {
            self.updateDistance()
            self.lastARDistanceUpdateTime = CACurrentMediaTime()
            print("updated ARDistance")
        }
    }
    
    func updateDistance() {
        print("Last UPdated Time: \(lastARDistanceUpdateTime)")
        print("Time: \(CACurrentMediaTime())")
        if self.useARDistanceMethod {
            self.distance = self.ARDistance
            //print("updated distance b/c AR")
        } else {
            self.distance = tan(self.pitch) * Double(self.dataViewController.getHeight())
            //print("updated distance b/c trig")
        }
        if self.distance < 0 {
            self.distanceString = "Distance: ???"
        } else if ((self.distance > 1200) || ((CACurrentMediaTime() - self.lastARDistanceUpdateTime) > 3)) {
            self.distanceString = "Distance: N/A"
            self.distance = 1300.0
        } else {
            self.distanceString = "Distance: \(Int(self.distance/12))'\(Int(self.distance)%12)\""
        }
        print(self.distanceString)
        print(self.distance)
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
        self.ARSupported = ARBodyTrackingConfiguration.isSupported
        //self.ARSupported = false


        // Run a body tracking configration.
        if self.ARSupported {
            let configuration = ARBodyTrackingConfiguration()
            arView.session.run(configuration)
        } else {
            let configuration = ARWorldTrackingConfiguration()
            arView.session.run(configuration)
        }
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        //self.ARSupported = false
        do {
            try AVAudioSession.sharedInstance().setCategory(AVAudioSession.Category.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("uh oh, audio went wrong")
        }
        
        // Ensure to keep a strong reference to the motion manager otherwise you won't get updates
        
        print(motionManager.isDeviceMotionAvailable)
        if ARSupported {
            distanceMethodSegmentedControl.selectedSegmentIndex = 0
            self.useARDistanceMethod = true
        } else {
            distanceMethodSegmentedControl.selectedSegmentIndex = 1
            self.useARDistanceMethod = false
        }
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
        
        DispatchQueue.main.async{
            self.distanceDisplay.text = self.distanceString
        }
    }
    
    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        var minDistance = 100000.0
        if self.ARSupported {
            for anchor in anchors {
                guard let bodyAnchor = anchor as? ARBodyAnchor else { continue }
                let zDistance = Double(abs(bodyAnchor.transform.columns.3.z - (arView.session.currentFrame?.camera.transform.columns.3.z)!))
                let xDistance = Double(abs(bodyAnchor.transform.columns.3.x - (arView.session.currentFrame?.camera.transform.columns.3.x)!))
                let distance = sqrt(pow(xDistance, 2) + pow(zDistance, 2))
                if distance < minDistance {
                    minDistance = distance
                }
            }
        }
        self.ARDistance = minDistance * 39.3701 //convert meters to inches
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        sessionQueue.async {
            switch self.setupResult {
            case .success:
                print("good job")
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
    }

    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    
    // Communicate with the session and other session objects on this queue.
    private let sessionQueue = DispatchQueue(label: "session queue")
    
    private var setupResult: SessionSetupResult = .success
    
    @objc dynamic var videoDeviceInput: AVCaptureDeviceInput!
    
    @IBOutlet private weak var previewView: PreviewView!
    
    
    func yell() {
        let utterance = AVSpeechUtterance(string: DataViewController.sayThisText)
        self.synthesizer.speak(utterance)
    }
    
    
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
    
    private var keyValueObservations = [NSKeyValueObservation]()
    /// - Tag: ObserveInterruption

    

    
    @objc
    func subjectAreaDidChange(notification: NSNotification) {
        let devicePoint = CGPoint(x: 0.5, y: 0.5)
        focus(with: .continuousAutoFocus, exposureMode: .continuousAutoExposure, at: devicePoint, monitorSubjectAreaChange: false)
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
    
    @objc
    private func sessionInterruptionEnded(notification: NSNotification) {
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
