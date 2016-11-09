//
//  STActivitiesChartView.swift
//  STStrava
//
//  Created by Nicolas Seriot on 12/11/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

// other_athlete activities
// https://www.strava.com/api/v3/athletes/9228133/activities?access_token=xxx
// {"message":"Authorization Error","errors":[]}
// -> probably, key for official client is needed

import UIKit

let LEFT_SCALE_WIDTH : Double = 30
let BOTTOM_SCALE_HEIGHT : Double = 30
let MAX_SECONDS : Int = Int(60 * 60 * 6.5)
let MAX_METERS : Int = 50000
let ACTIVITY_RADIUS = 4

func textWidth(_ text:NSString, font:UIFont, context: NSStringDrawingContext?) -> CGFloat {
    let maxSize : CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: font.pointSize)
    let textRect : CGRect = text.boundingRect(
        with: maxSize,
        options: NSStringDrawingOptions.usesLineFragmentOrigin,
        attributes: [NSFontAttributeName: font],
        context: context)
    return textRect.size.width
}

class ActivitiesChartView: UIView {
    
    fileprivate var activities : [Activity]
    
    fileprivate var athlete : Athlete?
    fileprivate var maxElevationMetersRounded : Int = 0
    fileprivate var totalDistance : Double?
    fileprivate var totalDuration : Int?
    fileprivate var firstDate : Date?
    fileprivate var lastDate : Date?
    
    override init(frame: CGRect) {
        self.activities = []
        super.init(frame:frame)
        self.maxElevationMetersRounded = 0
        self.backgroundColor = UIColor.white
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func drawInContext(_ context : CGContext) {
        context.setAllowsAntialiasing(true) // smaller file size when true
        
        context.setFillColor(UIColor.white.cgColor)
        context.fill(self.frame)
        
        drawBottomScale(context)
        drawLeftScale(context)
        drawTitleAndSubtitles(context)
        drawElevationLegend(context)
        drawPaces(context)
        
        for (index, a) in self.activities.enumerated() {
            let isLastActivity = index == activities.count-1
            drawActivityDot(context, activity:a, highlight:isLastActivity)
            if(isLastActivity) {
                drawLegendWithActivityDetails(context, activity:a)
            }
        }
    }
    
    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        drawInContext(context)
    }
    
    func xForSeconds(_ seconds:Int) -> Double {
        let xAxisWidth = Double(self.frame.size.width) - LEFT_SCALE_WIDTH
        return LEFT_SCALE_WIDTH + xAxisWidth * Double(seconds) / Double(MAX_SECONDS)
    }
    
    func yForMeters(_ meters:Double) -> Double {
        let yAxisHeight = Double(self.frame.size.height) - BOTTOM_SCALE_HEIGHT
        return Double(self.frame.size.height) - BOTTOM_SCALE_HEIGHT - yAxisHeight * meters / Double(MAX_METERS)
    }
    
    func maxElevationMetersRounded(_ activities:[Activity]) -> Int {
        guard activities.count > 0 else { return 0 }
        
        let maxElevation = activities.map{$0.elevationGain}.max()
        guard let existingMaxElevation = maxElevation else {
            return 0
        }
        
        let maxElevationRounded = (existingMaxElevation + 100) - (existingMaxElevation + 100).truncatingRemainder(dividingBy: 100)
        return Int(maxElevationRounded)
    }
    
    func colorForElevationGain(_ elevationMeters:Double) -> UIColor {
        let maxElevationMeters : Int = self.maxElevationMetersRounded
        let r = min(elevationMeters, Double(maxElevationMeters)) / Double(maxElevationMeters)
        let g = 1.0 - r
        let b = 0.0
        
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(1.0))
    }
    
    func drawText(_ context : CGContext, x: CGFloat, y: CGFloat, text : String, rotationAngle : CGFloat) {
        
        let font = UIFont.systemFont(ofSize: 14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.black]
        
        context.saveGState()
        
        if(rotationAngle != 0.0) {
            let width : CGFloat = 0.0 //textWidth(text, font: font, context: nil)
            context.translateBy(x: x + width / 2.0, y: y);
            context.rotate(by: rotationAngle)
            context.translateBy(x: -x - width / 2.0, y: -y);
        }
        
        text.draw(at: CGPoint(x: x, y: y), withAttributes: attr)
        
        context.restoreGState()
    }
    
    func drawBottomScale(_ context: CGContext) {
        
        context.saveGState()
        
        let color = UIColor.black
        context.setStrokeColor(color.cgColor)
        context.move(to: CGPoint(x: CGFloat(LEFT_SCALE_WIDTH), y: self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)))
        context.addLine(to: CGPoint(x: self.frame.size.width, y: self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)))
        
        for tick120Seconds in stride(from: (10*60), through: MAX_SECONDS, by: 10*60) {
            let isMajorTick = tick120Seconds % (30*60) == 0
            let x = xForSeconds(tick120Seconds)
            let tickStart = isMajorTick ? 0 : self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)
            let tickStop = isMajorTick ? self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 10 : self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 5
            context.move(to: CGPoint(x: CGFloat(x), y: CGFloat(tickStart)))
            context.addLine(to: CGPoint(x: CGFloat(x), y: CGFloat(tickStop)))
            
            let hours : Int = tick120Seconds / 3600
            let minutes : Int = (tick120Seconds % 3600) / 60
            
            let minutesString = String(format: "%02d", minutes)
            
            if isMajorTick {
                drawText(context, x: CGFloat(x-15), y: CGFloat(self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 10), text: "\(hours):\(minutesString)", rotationAngle: 0)
            }
        }
        
        context.strokePath()
        
        context.restoreGState()
    }
    
    func drawLeftScale(_ context: CGContext) {
        
        context.saveGState()
        
        let color = UIColor.black
        context.setStrokeColor(color.cgColor)
        context.move(to: CGPoint(x: CGFloat(LEFT_SCALE_WIDTH), y: 0))
        context.addLine(to: CGPoint(x: CGFloat(LEFT_SCALE_WIDTH), y: self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)))
        
        for tick1000Meters in stride(from: 1000.0, to: Double(MAX_METERS), by: 1000) {
//        for var tick1000Meters : Double = 1000; tick1000Meters < Double(MAX_METERS); tick1000Meters += 1000 {
            let isMajorTick = tick1000Meters.truncatingRemainder(dividingBy: 5000) == 0
            let y = yForMeters(tick1000Meters)
            let tickStart = isMajorTick ? LEFT_SCALE_WIDTH - 10 : LEFT_SCALE_WIDTH - 5
            let tickStop = isMajorTick ? self.frame.size.width : CGFloat(LEFT_SCALE_WIDTH)
            context.move(to: CGPoint(x: CGFloat(tickStart), y: CGFloat(y)))
            context.addLine(to: CGPoint(x: CGFloat(tickStop), y: CGFloat(y)))
            
            if(isMajorTick) {
                let tickKilometers : Int = Int(tick1000Meters / 1000)
                
                let text = "\(tickKilometers)"
                let font = UIFont.systemFont(ofSize: 14)
                
                drawText(
                    context,
                    x: CGFloat(LEFT_SCALE_WIDTH) - 12 - textWidth(text as NSString, font:font, context: nil),
                    y: CGFloat(y - 8),
                    text: text,
                    rotationAngle: 0)
            }
        }
        
        context.strokePath()
        
        context.restoreGState()
    }
    
    func drawPaces(_ context: CGContext) {
        
        let font = UIFont.systemFont(ofSize: 14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.lightGray]
        let yMetersForHorizontalDrawing : Double = 40000
        let xMinutesForVerticalDrawing = 190
        
        context.saveGState()
        
        context.setStrokeColor(UIColor.lightGray.cgColor)
        context.setLineWidth(0.5)
        
        for pace in stride(from: 3.5, through: 7.0, by: 0.5) {
//        for var pace : Double = 3.5; pace <= 7.0; pace += 0.5 {
            // draw pace line
            let xMaxKm : CGFloat = CGFloat(xForSeconds(Int(pace * 60.0 * Double(MAX_METERS) / 1000.0)))
            context.move(to: CGPoint(x: CGFloat(LEFT_SCALE_WIDTH), y: self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)))
            context.addLine(to: CGPoint(x: CGFloat(xMaxKm), y: CGFloat(0)))
            
            // draw pace text
            let text = "\(pace)'/Km"
            
            let deltaX = CGFloat(xMaxKm) - CGFloat(LEFT_SCALE_WIDTH)
            let deltaY = -1.0 * (self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
            let radians = atan(deltaY / deltaX)
            
            let paceWidth = textWidth(text as NSString, font:font, context: nil)
            
            let drawPaceVertically = xMaxKm + paceWidth / 2.0 > self.frame.size.width
            let pacePointX : CGFloat = drawPaceVertically ? CGFloat(xForSeconds(xMinutesForVerticalDrawing*60)) : CGFloat(xForSeconds(Int(pace * 60.0 * yMetersForHorizontalDrawing / 1000.0)))
            let pacePointY : CGFloat = drawPaceVertically ? CGFloat(yForMeters(Double(xMinutesForVerticalDrawing)/pace*1000)) : CGFloat(yForMeters(yMetersForHorizontalDrawing))
            let pacePoint = CGPoint(x: pacePointX, y: pacePointY)
            
            context.saveGState()
            
            context.translateBy(x: pacePoint.x, y: pacePoint.y);
            context.rotate(by: radians)
            context.translateBy(x: -1.0 * pacePoint.x, y: -1.0 * pacePoint.y);
            
            text.draw(at: pacePoint, withAttributes: attr)
            
            context.restoreGState()
        }
        
        context.strokePath()
        
        context.restoreGState()
    }
    
    func drawActivityDot(_ context: CGContext, activity: Activity, highlight: Bool) {
        
        context.saveGState()
        
        let x = self.xForSeconds(activity.seconds)
        let y = self.yForMeters(activity.meters)
        
        let elevationColor : UIColor = colorForElevationGain(activity.elevationGain)
        context.setStrokeColor(UIColor.black.cgColor)
        context.setFillColor(elevationColor.cgColor)
        context.setLineWidth(highlight ? 2 : 0.5)
        
        context.addEllipse(in: CGRect(
            x: CGFloat(x - Double(ACTIVITY_RADIUS)),
            y: CGFloat(y - Double(ACTIVITY_RADIUS)),
            width: CGFloat(ACTIVITY_RADIUS) * 2,
            height: CGFloat(ACTIVITY_RADIUS) * 2))
        
        context.drawPath(using: .fillStroke);
        
        context.restoreGState()
    }
    
    func drawTitleAndSubtitles(_ context: CGContext) {
        
        guard let existingAthlete = athlete else {
            return
        }
        
        guard self.totalDistance != nil else {
            return
        }
        
        let font = UIFont.systemFont(ofSize: 14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.black]
        
        context.saveGState()
        
        // frame
        
        let p0 = CGPoint(x: CGFloat(LEFT_SCALE_WIDTH + 10.0), y: 10)
        
        let titleFrame = CGRect(x: p0.x, y: p0.y, width: 235, height: 80)
        context.fill(titleFrame)
        context.stroke(titleFrame, width: 1.0)
        
        // labels
        
        let LINE_HEIGHT : CGFloat = 18
        
        let title = "Runner: \(existingAthlete.firstname!) \(existingAthlete.lastname!)"
        let l1 = CGPoint(x: p0.x + 10, y: p0.y + 5)
        title.draw(at: l1, withAttributes: attr)
        
        if(firstDate != nil && lastDate != nil) {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date1 = dateFormatter.string(from: self.firstDate!)
            let date2 = dateFormatter.string(from: self.lastDate!)
            let datesString = "Period: \(date1) - \(date2)"
            let l2 = CGPoint(x: l1.x, y: l1.y + LINE_HEIGHT)
            datesString.draw(at: l2, withAttributes: attr)
        }
        
        let distanceKm = String(format: "%0.2f", self.totalDistance!/1000)
        let distance = "Total distance: \(distanceKm) Km"
        let l3 = CGPoint(x: l1.x, y: l1.y + LINE_HEIGHT*2)
        distance.draw(at: l3, withAttributes: attr)
        
        let durationHours = String(format: "%02d", self.totalDuration!/3600)
        let durationMinutes = String(format: "%02d", (self.totalDuration! % 3600) / 60)
        let duration = "Total duration: \(durationHours):\(durationMinutes) hours"
        let l4 = CGPoint(x: l1.x, y: l3.y + LINE_HEIGHT)
        duration.draw(at: l4, withAttributes: attr)
        
        context.restoreGState()
    }
    
    func drawElevationLegend(_ context: CGContext) {
        
        guard athlete != nil else {
            return
        }
        
        let maxElevationMeters = self.maxElevationMetersRounded
        
        let font = UIFont.systemFont(ofSize: 14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.black]
        
        context.saveGState()
        
        // compute elevations
        
        var elevations : [Int] = []
        for elevation in stride(from: 0, through: maxElevationMeters, by: 100) {
//        for(var elevation = 0; elevation <= maxElevationMeters; elevation += 100) {
            elevations.append(elevation)
        }
        elevations = elevations.reversed()
        
        // frame
        
        /*
        p0---p1
        |    |
        p3---p2
        */
        
        let LINE_HEIGHT = 12
        let p0 = CGPoint(x: CGFloat(LEFT_SCALE_WIDTH + 10.0), y: 100)
        let p2 = CGPoint(x: p0.x + 90, y: p0.y + 30 + CGFloat(elevations.count * LINE_HEIGHT))
        
        let titleFrame = CGRect(x: p0.x, y: p0.y, width: p2.x - p0.x, height: p2.y - p0.y)
        context.fill(titleFrame)
        context.stroke(titleFrame, width: 1.0)
        
        let p = CGPoint(x: p0.x + 10, y: p0.y + 5)
        "Elevation".draw(at: p, withAttributes: attr)
        
        for elevation in elevations {
            let x = CGFloat(p.x + 5)
            let y = Double(p.y) + 25 + Double(maxElevationMeters - elevation) / 100.0 * Double(LINE_HEIGHT)
            
            let elevationColor : UIColor = colorForElevationGain(Double(elevation))
            
            context.setStrokeColor(UIColor.black.cgColor)
            context.setFillColor(elevationColor.cgColor)
            context.setLineWidth(0.5)
            
            context.addEllipse(in: CGRect(
                x: CGFloat(x - CGFloat(ACTIVITY_RADIUS)),
                y: CGFloat(y - Double(ACTIVITY_RADIUS)),
                width: CGFloat(ACTIVITY_RADIUS) * 2,
                height: CGFloat(ACTIVITY_RADIUS) * 2))
            
            context.drawPath(using: .fillStroke);
            
            if(elevation == maxElevationMeters) {
                let s = "+\(elevation) m"
                let p = CGPoint(x: x + CGFloat(10.0), y: CGFloat(y) - 10.0)
                s.draw(at: p, withAttributes: attr)
            }
        }
        
        context.restoreGState()
    }
    
    func drawLegendWithActivityDetails(_ context: CGContext, activity: Activity) {
        
        let font = UIFont.systemFont(ofSize: 14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.black]
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        context.saveGState()
        
        // frame
        
        let p2 = CGPoint(x: CGFloat(self.frame.size.width - 10), y: CGFloat(self.frame.size.height) - CGFloat(BOTTOM_SCALE_HEIGHT) - 10)
        let p0 = CGPoint(x: p2.x - 400, y: p2.y - 45)
        
        let titleFrame = CGRect(x: p0.x, y: p0.y, width: p2.x - p0.x, height: p2.y - p0.y)
        context.fill(titleFrame)
        context.stroke(titleFrame, width: 1.0)
        
        // labels
        
        let LINE_HEIGHT : CGFloat = 18
        
        let l1 = CGPoint(x: p0.x + 10, y: p0.y + 5)
        let prettyDate = dateFormatter.string(from: activity.date as Date)
        
        var dateAndPlace = "\(prettyDate)"
        if let city = activity.locationCity {
            dateAndPlace.append(", \(city)")
        }
        dateAndPlace.draw(at: l1, withAttributes: attr)
        let l2 =  CGPoint(x: l1.x, y: l1.y + LINE_HEIGHT)
        activity.name.draw(at: l2, withAttributes: attr)
        
        context.restoreGState()
    }
    
    func drawInImageContext() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.frame.size, false, UIScreen.main.scale)
        guard let context = UIGraphicsGetCurrentContext() as CGContext? else { fatalError() }
        drawInContext(context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let existingImage = image else { assertionFailure(); return UIImage() }
        return existingImage;
    }
    
    func setupGlobalStatsFromActivities(_ activities: [Activity]) {
        self.maxElevationMetersRounded = self.maxElevationMetersRounded(activities)
        self.totalDistance = activities.reduce(0) { $0! + $1.meters}
        self.totalDuration = activities.reduce(0) { $0! + $1.seconds}
        
        self.firstDate = activities.first?.date as Date?
        self.lastDate = activities.last?.date as Date?
    }
    
    func setData(_ athlete: Athlete, activities: [Activity]) {
        self.athlete = athlete
        self.activities = activities
        self.setupGlobalStatsFromActivities(activities)
        self.setNeedsDisplay()
    }

    func setProgressiveData(_ athlete: Athlete, activities: [Activity]) {
        self.athlete = athlete
        self.activities = activities
    }

    
    //        /*
    //        pierrick 434391
    //        sebastien 9228133
    //        */
    //        api.fetchFriendsActivities(434391) { (result) -> () in
    //
    //            switch(result) {
    //            case let .Success(activities):
    //
    //                if let otherAthlete = activities.first?.athlete {
    //                    self.athlete = otherAthlete
    //                }
    //
    //                self.activities = activities
    //
    //                self.setupGlobalStatsFromActivities(activities)
    //
    //                self.setNeedsDisplay()
    //
    //                self.createAnimatedGIF({ (gifPath) -> () in
    //                    print("--", gifPath)
    //                })
    //
    //            case let .Failure(error):
    //                print(error)
    //                return
    //            }
    //        }
    
}

