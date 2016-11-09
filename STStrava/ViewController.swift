//
//  ViewController.swift
//  STStrava
//
//  Created by nst on 05/11/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

import UIKit
import MessageUI

class ViewController: UIViewController, MFMailComposeViewControllerDelegate {
    
    @IBOutlet var connectButton : UIButton!
    @IBOutlet var disconnectButton : UIButton!
    @IBOutlet var fetchDataButton : UIButton!
    @IBOutlet var displayDataButton : UIButton!
    @IBOutlet var createGIFButton : UIButton!
    @IBOutlet var statusLabel : UILabel!
    
    fileprivate var athlete: Athlete?
    fileprivate var activities: [Activity]?
    
    # enter your client ID and client secret below
    fileprivate let stravaAPI : StravaAPI = {
        let storedAccessToken = UserDefaults.standard.value(forKey: "StravaAccessToken") as? String
        return StravaAPI(
            clientID: "",
            clientSecret: "",
            storedAccessToken: storedAccessToken)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // subviews
        
        self.connectButton = UIButton(type: UIButtonType.custom)
        let connectImage = UIImage(named: "ConnectWithStrava")
        self.connectButton.setImage(connectImage, for: UIControlState())
        self.connectButton.addTarget(self, action:#selector(ViewController.connectButtonClicked(_:)), for: UIControlEvents.touchUpInside)
        self.connectButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(connectButton!)

        self.disconnectButton = UIButton(type: UIButtonType.system)
        self.disconnectButton.setTitle("Disconnect", for: UIControlState())
        self.disconnectButton.addTarget(self, action:#selector(ViewController.disconnectButtonClicked(_:)), for: UIControlEvents.touchUpInside)
        self.disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(disconnectButton!)

        self.fetchDataButton = UIButton(type: UIButtonType.system)
        self.fetchDataButton.setTitle("Fetch Data", for: UIControlState())
        self.fetchDataButton.addTarget(self, action:#selector(ViewController.fetchData(_:)), for: UIControlEvents.touchUpInside)
        self.fetchDataButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(fetchDataButton!)

        self.displayDataButton = UIButton(type: UIButtonType.system)
        self.displayDataButton.setTitle("Display Data", for: UIControlState())
        self.displayDataButton.addTarget(self, action:#selector(ViewController.displayData(_:)), for: UIControlEvents.touchUpInside)
        self.displayDataButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(displayDataButton!)

        self.createGIFButton = UIButton(type: UIButtonType.system)
        self.createGIFButton.setTitle("Send GIF by Email", for: UIControlState())
        self.createGIFButton.addTarget(self, action:#selector(ViewController.createAndSendGIF(_:)), for: UIControlEvents.touchUpInside)
        self.createGIFButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(createGIFButton!)

        self.statusLabel = UILabel()
        self.statusLabel.textAlignment = .center
        self.statusLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(statusLabel)
        
        // autolayout
        
        let views = ["connectButton":connectButton, "statusLabel":statusLabel, "disconnectButton":disconnectButton, "fetchDataButton":fetchDataButton, "displayDataButton":displayDataButton, "createGIFButton":createGIFButton] as [String : Any]
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-20-[connectButton]-20-[statusLabel]-20-[disconnectButton]-20-[fetchDataButton]-20-[displayDataButton]-20-[createGIFButton]", options:NSLayoutFormatOptions(), metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[connectButton]-|", options:.alignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[statusLabel]-|", options:.alignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[disconnectButton]-|", options:.alignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[fetchDataButton]-|", options:.alignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[displayDataButton]-|", options:.alignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-[createGIFButton]-|", options:.alignAllCenterX, metrics:nil, views:views))
        
        self.updateDisplayAccordingToStravaAPIConnection()

        // notifications
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "OpenURL"), object: nil, queue: nil) { (notification) -> Void in
            if let existingURL = (notification as NSNotification).userInfo?["URL"] as? URL {
                UIApplication.shared.openURL(existingURL)
            }
        }
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "StravaAPIHasAccessToken"), object: nil, queue: nil) { [unowned self] (notification) -> Void in
            print("-- StravaAPIHasAccessToken")
            
            if let accessToken = (notification as NSNotification).userInfo?["accessToken"] as? String {
                UserDefaults.standard.set(accessToken, forKey:"StravaAccessToken")
            }
            
            self.updateDisplayAccordingToStravaAPIConnection()
        }
    }
    
    func updateDisplayAccordingToStravaAPIConnection() {
        
        let accessToken = self.stravaAPI.accessToken
        
        let isConnected = accessToken != nil
        
        self.connectButton.isHidden = isConnected
        
        let status = isConnected ? "Connected with token: \(accessToken!)" : ""
        
        self.statusLabel.text = status
        
        self.disconnectButton.isHidden = !isConnected

        self.fetchDataButton.isHidden = !isConnected
        
        self.displayDataButton.isHidden = self.athlete == nil || self.activities == nil

        self.createGIFButton.isHidden = self.displayDataButton.isHidden
}
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "OpenURL"), object: nil)
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "StravaAPIHasAccessToken"), object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func createAnimatedGIF(_ completionHandler:(_ gifPath:String?) -> ()) {
        
        let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        let pathURL = URL(fileURLWithPath: path)
        let fileURL = pathURL.appendingPathComponent("activities.gif")
        let fileURLPath = fileURL.path
        
        let gifCreator = STAnimatedGIFCreator(destinationPath: fileURLPath, loop: false)
        guard let existingGIFCreator = gifCreator else { return }
        
        guard let existingAthlete = self.athlete else { return }
        guard let existingActivities = self.activities else { return }
        
        var localActivities = existingActivities
        
        for i in 0...localActivities.count {
            
            let chartView = ActivitiesChartView(frame: self.view.frame)
            chartView.setupGlobalStatsFromActivities(localActivities)
            let subActivities = Array(localActivities[0..<i])
            chartView.setProgressiveData(existingAthlete, activities: subActivities)
            
            let image : UIImage = chartView.drawInImageContext()
            
            existingGIFCreator.addImage(image, duration: 0.2)
        }
        
        let success = existingGIFCreator.writeFile()
        
        completionHandler(success ? fileURLPath : nil)
    }
    
    
    @IBAction func connectButtonClicked(_ sender: UIButton!) {
        self.statusLabel.text = "Fetching auth. code and exchanging it for access token..."
        self.stravaAPI.startAuthorizationProcess(redirectURI: "STStrava://seriot.ch/ststrava.php")
    }
    
    @IBAction func disconnectButtonClicked(_ sender: UIButton!) {
        UserDefaults.standard.removeObject(forKey: "StravaAccessToken")
        
        let actionSheetController: UIAlertController = UIAlertController(title: "Confirmation", message: "Do you really want to disconnect?", preferredStyle: .actionSheet)
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .cancel) { action -> Void in
        }

        let disconnectAction = UIAlertAction(title: "Disconnect", style: .destructive) { action -> Void in
            self.stravaAPI.forgetAccessToken()
            self.updateDisplayAccordingToStravaAPIConnection()
        }

        actionSheetController.addAction(cancelAction)
        actionSheetController.addAction(disconnectAction)
        
        actionSheetController.popoverPresentationController?.sourceView = sender as UIView
        
        self.present(actionSheetController, animated: true, completion: nil)
    }
    
    @IBAction func fetchData(_ sender: UIButton!) {
        
        self.statusLabel.text = ""
        
        self.stravaAPI.fetchAthlete { [unowned self] (result) -> () in
            
            switch result {
            case let .success(athlete):
                
                self.athlete = athlete
                
                self.stravaAPI.fetchActivities() { [unowned self] (result) -> () in
                    
                    switch result {
                    case let .success(activities):

                        self.activities = activities
                        
                        self.updateDisplayAccordingToStravaAPIConnection()

                    case let .failure(error):
                        
                        self.statusLabel.text = error.localizedDescription
                    }
                }
                
            case let .failure(error):
                self.statusLabel.text = error.localizedDescription
            }
        }
    }
    
    @IBAction func displayData(_ sender: UIButton!) {
        let chartView = ActivitiesChartView(frame: self.view.frame)
        chartView.setData(self.athlete!, activities: self.activities!) // TODO: don't force unwrap
        
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        chartView.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let imageView = UIImageView(frame: self.view.frame)
        imageView.image = image
        self.view.addSubview(imageView)
        
        let tap = UITapGestureRecognizer(target:self, action:#selector(ViewController.imageViewTapped(_:)))
        imageView.addGestureRecognizer(tap)
        imageView.isUserInteractionEnabled = true
    }

    @IBAction func imageViewTapped(_ gestureRecognizer: UITapGestureRecognizer) {
        print("imageViewTapped:")
        
        if let view = gestureRecognizer.view {
            view.removeFromSuperview()
        }
    }
    
    @IBAction func createAndSendGIF(_ sender: UIButton!) {
        self.createAnimatedGIF({ [unowned self] (gifPath) -> () in
            
            if let existingGifPath = gifPath {
                print("--", existingGifPath)
                
                self.sendGIFByEmail(existingGifPath)
            }
        })
    }
    
    func sendGIFByEmail(_ path:String) {
        let data = try? Data(contentsOf: URL(fileURLWithPath: path))
        guard let existingData = data else {
            return
        }
        
        var subject = "STStrava Animated GIF"
        if let athleteUsername = athlete?.username {
            subject += " for \(athleteUsername)"
        }
        
        let mc = MFMailComposeViewController()
        mc.mailComposeDelegate = self
        mc.setSubject(subject)
        mc.setMessageBody("", isHTML: false)
        mc.addAttachmentData(existingData, mimeType: "image/gif", fileName: (path as NSString).lastPathComponent)
        
        self.present(mc, animated: true, completion: {})
    }
    
    func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
        /*
        switch result.rawValue {
        case MFMailComposeResultCancelled.rawValue:
            print("Mail cancelled")
        case MFMailComposeResultSaved.rawValue:
            print("Mail saved")
        case MFMailComposeResultSent.rawValue:
            print("Mail sent")
        case MFMailComposeResultFailed.rawValue:
            print("Mail sent failure: \(error!.localizedDescription)")
        default:
            break
        }
        controller.dismissViewControllerAnimated(true, completion: nil)
         */
    }
}
