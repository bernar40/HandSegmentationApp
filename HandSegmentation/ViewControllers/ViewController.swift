// Copyright 2019 The TensorFlow Authors. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import UIKit

class ViewController: UIViewController {

  // MARK: Storyboards Connections
  @IBOutlet weak var previewView: PreviewView!
  @IBOutlet weak var cameraUnavailableLabel: UILabel!
    
  // MARK: Constants
  private let screenWidth = UIScreen.main.bounds.width
  private let screenHeight = UIScreen.main.bounds.height

  // MARK: Instance Variables

  // Holds the results at any time
    private var result: Result<Any>?
  private var previousInferenceTimeMs: TimeInterval = Date.distantPast.timeIntervalSince1970 * 1000

  // MARK: Controllers that manage functionality
  private lazy var cameraFeedManager = CameraFeedManager(previewView: previewView)

    /// Image segmentator instance that runs image segmentation.
    private var imageSegmentator: ImageSegmentator?

    /// Target image to run image segmentation on.
    private var targetImage: UIImage?

    /// Processed (e.g center cropped)) image from targetImage that is fed to imageSegmentator.
    private var segmentationInput: UIImage?

    /// Image segmentation result.
    private var segmentationResult: SegmentationResult?


  // MARK: View Handling Methods
  override func viewDidLoad() {
    super.viewDidLoad()

    // Initialize an image segmentator instance.
      ImageSegmentator.newInstance { result in
        switch result {
        case let .success(segmentator):
          // Store the initialized instance for use.
          self.imageSegmentator = segmentator

        case .error(_):
          print("Failed to initialize.")
        }
      }
    cameraFeedManager.delegate = self
  }

  override func didReceiveMemoryWarning() {
    super.didReceiveMemoryWarning()
    // Dispose of any resources that can be recreated.
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    cameraFeedManager.checkCameraConfigurationAndStartSession()
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    cameraFeedManager.stopSession()
  }

  override var preferredStatusBarStyle: UIStatusBarStyle {
    return .lightContent
  }

  // MARK: Button Actions
  @IBAction func onClickResumeButton(_ sender: Any) {

    cameraFeedManager.resumeInterruptedSession { (complete) in

      if complete {
        self.cameraUnavailableLabel.isHidden = true
      }
      else {
        self.presentUnableToResumeSessionAlert()
      }
    }
  }

  func presentUnableToResumeSessionAlert() {
    let alert = UIAlertController(
      title: "Unable to Resume Session",
      message: "There was an error while attempting to resume session.",
      preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))

    self.present(alert, animated: true)
  }
}


// MARK: CameraFeedManagerDelegate Methods
extension ViewController: CameraFeedManagerDelegate {
    
  func didOutput(pixelBuffer: CVPixelBuffer) {
    runSegmentation(pixelBuffer: pixelBuffer)
  }

  // MARK: Session Handling Alerts
  func sessionRunTimeErrorOccured() {

    // Handles session run time error by updating the UI and providing a button if session can be manually resumed.
  }

  func sessionWasInterrupted(canResumeManually resumeManually: Bool) {

    // Updates the UI when session is interupted.
    if resumeManually {
    }
    else {
      self.cameraUnavailableLabel.isHidden = false
    }
  }

  func sessionInterruptionEnded() {

    // Updates UI once session interruption has ended.
    if !self.cameraUnavailableLabel.isHidden {
      self.cameraUnavailableLabel.isHidden = true
    }
  }

  func presentVideoConfigurationErrorAlert() {

    let alertController = UIAlertController(title: "Confirguration Failed", message: "Configuration of camera has failed.", preferredStyle: .alert)
    let okAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
    alertController.addAction(okAction)

    present(alertController, animated: true, completion: nil)
  }

  func presentCameraPermissionsDeniedAlert() {

    let alertController = UIAlertController(title: "Camera Permissions Denied", message: "Camera permissions have been denied for this app. You can change this by going to Settings", preferredStyle: .alert)

    let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
    let settingsAction = UIAlertAction(title: "Settings", style: .default) { (action) in

      UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!, options: [:], completionHandler: nil)
    }

    alertController.addAction(cancelAction)
    alertController.addAction(settingsAction)

    present(alertController, animated: true, completion: nil)

  }

  /** This method runs the live camera pixelBuffer through tensorFlow to get the result.
   */
       // Run image segmentation.
      func runSegmentation(pixelBuffer: CVPixelBuffer) {

        // Rotate target image to .up orientation to avoid potential orientation misalignment.


        // Run image segmentation.
        imageSegmentator?.runSegmentation(
            onFrame: pixelBuffer,
          completion: { result in
            // Show the segmentation result on screen
            switch result {
            case let .success(segmentationResult):
              self.segmentationResult = segmentationResult
              self.previewView.addSubview(UIImageView(image:  self.resizeImage(image: segmentationResult.overlayImage, targetSize: CGSize(width: self.screenWidth, height: self.screenHeight))))
            case let .error(error):
              print(error.localizedDescription)
            }
          })
      }
}

// MARK: Auxiliary functions
extension ViewController {
    
    private func resizeImage(image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Figure out what our orientation is, and use that to form the rectangle
        var newSize: CGSize
        if(widthRatio > heightRatio) {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio,  height: size.height * widthRatio)
        }

        // This is the rect that we've calculated out and this is what is actually used below
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        // Actually do the resizing to the rect using the ImageContext stuff
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}
