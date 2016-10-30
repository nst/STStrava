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
    
    private var athlete: Athlete?
    private var activities: [Activity]?
    
    # enter your client ID and client secret below
    private let stravaAPI : StravaAPI = {
        let storedAccessToken = NSUserDefaults.standardUserDefaults().valueForKey("StravaAccessToken") as? String
        return StravaAPI(
            clientID: "",
            clientSecret: "",
            storedAccessToken: storedAccessToken)
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // subviews
        
        self.connectButton = UIButton(type: UIButtonType.Custom)
        let connectImage = UIImage(named: "ConnectWithStrava")
        self.connectButton.setImage(connectImage, forState: UIControlState.Normal)
        self.connectButton.addTarget(self, action:#selector(ViewController.connectButtonClicked(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.connectButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(connectButton!)

        self.disconnectButton = UIButton(type: UIButtonType.System)
        self.disconnectButton.setTitle("Disconnect", forState: .Normal)
        self.disconnectButton.addTarget(self, action:#selector(ViewController.disconnectButtonClicked(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.disconnectButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(disconnectButton!)

        self.fetchDataButton = UIButton(type: UIButtonType.System)
        self.fetchDataButton.setTitle("Fetch Data", forState: .Normal)
        self.fetchDataButton.addTarget(self, action:#selector(ViewController.fetchData(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.fetchDataButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(fetchDataButton!)

        self.displayDataButton = UIButton(type: UIButtonType.System)
        self.displayDataButton.setTitle("Display Data", forState: .Normal)
        self.displayDataButton.addTarget(self, action:#selector(ViewController.displayData(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.displayDataButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(displayDataButton!)

        self.createGIFButton = UIButton(type: UIButtonType.System)
        self.createGIFButton.setTitle("Send GIF by Email", forState: .Normal)
        self.createGIFButton.addTarget(self, action:#selector(ViewController.createAndSendGIF(_:)), forControlEvents: UIControlEvents.TouchUpInside)
        self.createGIFButton.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(createGIFButton!)

        self.statusLabel = UILabel()
        self.statusLabel.textAlignment = .Center
        self.statusLabel.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(statusLabel)
        
        // autolayout
        
        let views = ["connectButton":connectButton, "statusLabel":statusLabel, "disconnectButton":disconnectButton, "fetchDataButton":fetchDataButton, "displayDataButton":displayDataButton, "createGIFButton":createGIFButton]
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("V:|-20-[connectButton]-20-[statusLabel]-20-[disconnectButton]-20-[fetchDataButton]-20-[displayDataButton]-20-[createGIFButton]", options:.DirectionLeadingToTrailing, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[connectButton]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[statusLabel]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[disconnectButton]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[fetchDataButton]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[displayDataButton]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        self.view.addConstraints(NSLayoutConstraint.constraintsWithVisualFormat("H:|-[createGIFButton]-|", options:.AlignAllCenterX, metrics:nil, views:views))
        
        self.updateDisplayAccordingToStravaAPIConnection()

        // notifications
        
        NSNotificationCenter.defaultCenter().addObserverForName("OpenURL", object: nil, queue: nil) { (notification) -> Void in
            if let existingURL = notification.userInfo?["URL"] as? NSURL {
                UIApplication.sharedApplication().openURL(existingURL)
            }
        }
        
        NSNotificationCenter.defaultCenter().addObserverForName("StravaAPIHasAccessToken", object: nil, queue: nil) { [unowned self] (notification) -> Void in
            print("-- StravaAPIHasAccessToken")
            
            if let accessToken = notification.userInfo?["accessToken"] as? String {
                NSUserDefaults.standardUserDefaults().setObject(accessToken, forKey:"StravaAccessToken")
            }
            
            self.updateDisplayAccordingToStravaAPIConnection()
        }
    }
    
    func updateDisplayAccordingToStravaAPIConnection() {
        
        let accessToken = self.stravaAPI.accessToken
        
        let isConnected = accessToken != nil
        
        self.connectButton.hidden = isConnected
        
        let status = isConnected ? "Connected with token: \(accessToken!)" : ""
        
        self.statusLabel.text = status
        
        self.disconnectButton.hidden = !isConnected

        self.fetchDataButton.hidden = !isConnected
        
        self.displayDataButton.hidden = self.athlete == nil || self.activities == nil

        self.createGIFButton.hidden = self.displayDataButton.hidden
}
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "OpenURL", object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "StravaAPIHasAccessToken", object: nil)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func createAnimatedGIF(completionHandler:(gifPath:String?) -> ()) {
        
        let path = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
        let pathURL = NSURL(fileURLWithPath: path)
        guard let fileURL = pathURL.URLByAppendingPathComponent("activities.gif") else { return }
        guard let fileURLPath = fileURL.path else { return }
        
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
        
        completionHandler(gifPath: success ? fileURLPath : nil)
    }
    
    
    @IBAction func connectButtonClicked(sender: UIButton!) {
        self.statusLabel.text = "Fetching auth. code and exchanging it for access token..."
        self.stravaAPI.startAuthorizationProcess(redirectURI: "STStrava://seriot.ch/ststrava.php")
    }
    
    @IBAction func disconnectButtonClicked(sender: UIButton!) {
        NSUserDefaults.standardUserDefaults().removeObjectForKey("StravaAccessToken")
        
        let actionSheetController: UIAlertController = UIAlertController(title: "Confirmation", message: "Do you really want to disconnect?", preferredStyle: .ActionSheet)
        
        let cancelAction: UIAlertAction = UIAlertAction(title: "Cancel", style: .Cancel) { action -> Void in
        }

        let disconnectAction = UIAlertAction(title: "Disconnect", style: .Destructive) { action -> Void in
            self.stravaAPI.forgetAccessToken()
            self.updateDisplayAccordingToStravaAPIConnection()
        }

        actionSheetController.addAction(cancelAction)
        actionSheetController.addAction(disconnectAction)
        
        actionSheetController.popoverPresentationController?.sourceView = sender as UIView
        
        self.presentViewController(actionSheetController, animated: true, completion: nil)
    }
    
    @IBAction func fetchData(sender: UIButton!) {
        
        self.statusLabel.text = ""
        
        self.stravaAPI.fetchAthlete { [unowned self] (result) -> () in
            
            switch result {
            case let .Success(athlete):
                
                self.athlete = athlete
                
                self.stravaAPI.fetchActivities() { [unowned self] (result) -> () in
                    
                    switch result {
                    case let .Success(activities):

                        self.activities = activities
                        
                        self.updateDisplayAccordingToStravaAPIConnection()

                    case let .Failure(error):
                        
                        self.statusLabel.text = error.localizedDescription
                    }
                }
                
            case let .Failure(error):
                self.statusLabel.text = error.localizedDescription
            }
        }
    }
    
    @IBAction func displayData(sender: UIButton!) {
        let chartView = ActivitiesChartView(frame: self.view.frame)
        chartView.setData(self.athlete!, activities: self.activities!) // TODO: don't force unwrap
        
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, true, 0)
        chartView.drawViewHierarchyInRect(view.bounds, afterScreenUpdates: true)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        let imageView = UIImageView(frame: self.view.frame)
        imageView.image = image
        self.view.addSubview(imageView)
        
        let tap = UITapGestureRecognizer(target:self, action:#selector(ViewController.imageViewTapped(_:)))
        imageView.addGestureRecognizer(tap)
        imageView.userInteractionEnabled = true
    }

    @IBAction func imageViewTapped(gestureRecognizer: UITapGestureRecognizer) {
        print("imageViewTapped:")
        
        if let view = gestureRecognizer.view {
            view.removeFromSuperview()
        }
    }
    
    @IBAction func createAndSendGIF(sender: UIButton!) {
        self.createAnimatedGIF({ [unowned self] (gifPath) -> () in
            
            if let existingGifPath = gifPath {
                print("--", existingGifPath)
                
                self.sendGIFByEmail(existingGifPath)
            }
        })
    }
    
    func sendGIFByEmail(path:String) {
        let data = NSData(contentsOfFile: path)
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
        
        self.presentViewController(mc, animated: true, completion: {})
    }
    
    func mailComposeController(controller: MFMailComposeViewController, didFinishWithResult result: MFMailComposeResult, error: NSError?) {
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
