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
let MAX_SECONDS : Int = Int(60 * 60 * 3.5)
let MAX_METERS : Int = 43000
let ACTIVITY_RADIUS = 4

func textWidth(text:NSString, font:UIFont, context: NSStringDrawingContext?) -> CGFloat {
    let maxSize : CGSize = CGSizeMake(CGFloat.max, font.pointSize)
    let textRect : CGRect = text.boundingRectWithSize(
        maxSize,
        options: NSStringDrawingOptions.UsesLineFragmentOrigin,
        attributes: [NSFontAttributeName: font],
        context: context)
    return textRect.size.width
}

class ActivitiesChartView: UIView {
    
    private var activities : [Activity]
    
    private var athlete : Athlete?
    private var maxElevationMetersRounded : Int = 0
    private var totalDistance : Double?
    private var totalDuration : Int?
    private var firstDate : NSDate?
    private var lastDate : NSDate?
    
    override init(frame: CGRect) {
        self.activities = []
        super.init(frame:frame)
        self.maxElevationMetersRounded = 0
        self.backgroundColor = UIColor.whiteColor()
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func drawInContext(context : CGContextRef) {
        CGContextSetAllowsAntialiasing(context, true) // smaller file size when true
        
        CGContextSetFillColorWithColor(context, UIColor.whiteColor().CGColor)
        CGContextFillRect(context, self.frame)
        
        drawBottomScale(context)
        drawLeftScale(context)
        drawTitleAndSubtitles(context)
        drawElevationLegend(context)
        drawPaces(context)
        
        for (index, a) in self.activities.enumerate() {
            let isLastActivity = index == activities.count-1
            drawActivityDot(context, activity:a, highlight:isLastActivity)
            if(isLastActivity) {
                drawLegendWithActivityDetails(context, activity:a)
            }
        }
    }
    
    override func drawRect(rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext() else { return }
        
        drawInContext(context)
    }
    
    func xForSeconds(seconds:Int) -> Double {
        let xAxisWidth = Double(self.frame.size.width) - LEFT_SCALE_WIDTH
        return LEFT_SCALE_WIDTH + xAxisWidth * Double(seconds) / Double(MAX_SECONDS)
    }
    
    func yForMeters(meters:Double) -> Double {
        let yAxisHeight = Double(self.frame.size.height) - BOTTOM_SCALE_HEIGHT
        return Double(self.frame.size.height) - BOTTOM_SCALE_HEIGHT - yAxisHeight * meters / Double(MAX_METERS)
    }
    
    func maxElevationMetersRounded(activities:[Activity]) -> Int {
        guard activities.count > 0 else { return 0 }
        
        let maxElevation = activities.map{$0.elevationGain}.maxElement()
        guard let existingMaxElevation = maxElevation else {
            return 0
        }
        
        let maxElevationRounded = (existingMaxElevation + 100) - (existingMaxElevation + 100) % 100
        return Int(maxElevationRounded)
    }
    
    func colorForElevationGain(elevationMeters:Double) -> UIColor {
        let maxElevationMeters : Int = self.maxElevationMetersRounded
        let r = min(elevationMeters, Double(maxElevationMeters)) / Double(maxElevationMeters)
        let g = 1.0 - r
        let b = 0.0
        
        return UIColor(red: CGFloat(r), green: CGFloat(g), blue: CGFloat(b), alpha: CGFloat(1.0))
    }
    
    func drawText(context : CGContext?, x: CGFloat, y: CGFloat, text : String, rotationAngle : CGFloat) {
        
        let font = UIFont.systemFontOfSize(14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.blackColor()]
        
        CGContextSaveGState(context)
        
        if(rotationAngle != 0.0) {
            let width : CGFloat = 0.0 //textWidth(text, font: font, context: nil)
            CGContextTranslateCTM(context, x + width / 2.0, y);
            CGContextRotateCTM(context, rotationAngle)
            CGContextTranslateCTM(context, -x - width / 2.0, -y);
        }
        
        text.drawAtPoint(CGPointMake(x, y), withAttributes: attr)
        
        CGContextRestoreGState(context)
    }
    
    func drawBottomScale(context: CGContext?) {
        
        CGContextSaveGState(context)
        
        let color = UIColor.blackColor()
        CGContextSetStrokeColorWithColor(context, color.CGColor)
        CGContextMoveToPoint(context, CGFloat(LEFT_SCALE_WIDTH), self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
        CGContextAddLineToPoint(context, self.frame.size.width, self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
        
        for tick120Seconds in (10*60).stride(through: MAX_SECONDS, by: 10*60) {
            let isMajorTick = tick120Seconds % (30*60) == 0
            let x = xForSeconds(tick120Seconds)
            let tickStart = isMajorTick ? 0 : self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT)
            let tickStop = isMajorTick ? self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 10 : self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 5
            CGContextMoveToPoint(context, CGFloat(x), CGFloat(tickStart))
            CGContextAddLineToPoint(context, CGFloat(x), CGFloat(tickStop))
            
            let hours : Int = tick120Seconds / 3600
            let minutes : Int = (tick120Seconds % 3600) / 60
            
            let minutesString = String(format: "%02d", minutes)
            
            if isMajorTick {
                drawText(context, x: CGFloat(x-15), y: CGFloat(self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT) + 10), text: "\(hours):\(minutesString)", rotationAngle: 0)
            }
        }
        
        CGContextStrokePath(context)
        
        CGContextRestoreGState(context)
    }
    
    func drawLeftScale(context: CGContext?) {
        
        CGContextSaveGState(context)
        
        let color = UIColor.blackColor()
        CGContextSetStrokeColorWithColor(context, color.CGColor)
        CGContextMoveToPoint(context, CGFloat(LEFT_SCALE_WIDTH), 0)
        CGContextAddLineToPoint(context, CGFloat(LEFT_SCALE_WIDTH), self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
        
        for tick1000Meters in 1000.0.stride(to: Double(MAX_METERS), by: 1000) {
//        for var tick1000Meters : Double = 1000; tick1000Meters < Double(MAX_METERS); tick1000Meters += 1000 {
            let isMajorTick = tick1000Meters % 5000 == 0
            let y = yForMeters(tick1000Meters)
            let tickStart = isMajorTick ? LEFT_SCALE_WIDTH - 10 : LEFT_SCALE_WIDTH - 5
            let tickStop = isMajorTick ? self.frame.size.width : CGFloat(LEFT_SCALE_WIDTH)
            CGContextMoveToPoint(context, CGFloat(tickStart), CGFloat(y))
            CGContextAddLineToPoint(context, CGFloat(tickStop), CGFloat(y))
            
            if(isMajorTick) {
                let tickKilometers : Int = Int(tick1000Meters / 1000)
                
                let text = "\(tickKilometers)"
                let font = UIFont.systemFontOfSize(14)
                
                drawText(
                    context,
                    x: CGFloat(LEFT_SCALE_WIDTH) - 12 - textWidth(text, font:font, context: nil),
                    y: CGFloat(y - 8),
                    text: text,
                    rotationAngle: 0)
            }
        }
        
        CGContextStrokePath(context)
        
        CGContextRestoreGState(context)
    }
    
    func drawPaces(context: CGContext?) {
        
        let font = UIFont.systemFontOfSize(14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.lightGrayColor()]
        let yMetersForHorizontalDrawing : Double = 40000
        let xMinutesForVerticalDrawing = 190
        
        CGContextSaveGState(context)
        
        CGContextSetStrokeColorWithColor(context, UIColor.lightGrayColor().CGColor)
        CGContextSetLineWidth(context, 0.5)
        
        for pace in 3.5.stride(through: 7.0, by: 0.5) {
//        for var pace : Double = 3.5; pace <= 7.0; pace += 0.5 {
            // draw pace line
            let xMaxKm : CGFloat = CGFloat(xForSeconds(Int(pace * 60.0 * Double(MAX_METERS) / 1000.0)))
            CGContextMoveToPoint(context, CGFloat(LEFT_SCALE_WIDTH), self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
            CGContextAddLineToPoint(context, CGFloat(xMaxKm), CGFloat(0))
            
            // draw pace text
            let text = "\(pace)'/Km"
            
            let deltaX = CGFloat(xMaxKm) - CGFloat(LEFT_SCALE_WIDTH)
            let deltaY = -1.0 * (self.frame.size.height - CGFloat(BOTTOM_SCALE_HEIGHT))
            let radians = atan(deltaY / deltaX)
            
            let paceWidth = textWidth(text, font:font, context: nil)
            
            let drawPaceVertically = xMaxKm + paceWidth / 2.0 > self.frame.size.width
            let pacePointX : CGFloat = drawPaceVertically ? CGFloat(xForSeconds(xMinutesForVerticalDrawing*60)) : CGFloat(xForSeconds(Int(pace * 60.0 * yMetersForHorizontalDrawing / 1000.0)))
            let pacePointY : CGFloat = drawPaceVertically ? CGFloat(yForMeters(Double(xMinutesForVerticalDrawing)/pace*1000)) : CGFloat(yForMeters(yMetersForHorizontalDrawing))
            let pacePoint = CGPointMake(pacePointX, pacePointY)
            
            CGContextSaveGState(context)
            
            CGContextTranslateCTM(context, pacePoint.x, pacePoint.y);
            CGContextRotateCTM(context, radians)
            CGContextTranslateCTM(context, -1.0 * pacePoint.x, -1.0 * pacePoint.y);
            
            text.drawAtPoint(pacePoint, withAttributes: attr)
            
            CGContextRestoreGState(context)
        }
        
        CGContextStrokePath(context)
        
        CGContextRestoreGState(context)
    }
    
    func drawActivityDot(context: CGContext?, activity: Activity, highlight: Bool) {
        
        CGContextSaveGState(context)
        
        let x = self.xForSeconds(activity.seconds)
        let y = self.yForMeters(activity.meters)
        
        let elevationColor : UIColor = colorForElevationGain(activity.elevationGain)
        CGContextSetStrokeColorWithColor(context, UIColor.blackColor().CGColor)
        CGContextSetFillColorWithColor(context, elevationColor.CGColor)
        CGContextSetLineWidth(context, highlight ? 2 : 0.5)
        
        CGContextAddEllipseInRect(context, CGRectMake(
            CGFloat(x - Double(ACTIVITY_RADIUS)),
            CGFloat(y - Double(ACTIVITY_RADIUS)),
            CGFloat(ACTIVITY_RADIUS) * 2,
            CGFloat(ACTIVITY_RADIUS) * 2))
        
        CGContextDrawPath(context, .FillStroke);
        
        CGContextRestoreGState(context)
    }
    
    func drawTitleAndSubtitles(context: CGContext?) {
        
        guard let existingAthlete = athlete else {
            return
        }
        
        guard self.totalDistance != nil else {
            return
        }
        
        let font = UIFont.systemFontOfSize(14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.blackColor()]
        
        CGContextSaveGState(context)
        
        // frame
        
        let p0 = CGPointMake(CGFloat(LEFT_SCALE_WIDTH + 10.0), 10)
        
        let titleFrame = CGRectMake(p0.x, p0.y, 235, 80)
        CGContextFillRect(context, titleFrame)
        CGContextStrokeRectWithWidth(context, titleFrame, 1.0)
        
        // labels
        
        let LINE_HEIGHT : CGFloat = 18
        
        let title = "Runner: \(existingAthlete.firstname!) \(existingAthlete.lastname!)"
        let l1 = CGPointMake(p0.x + 10, p0.y + 5)
        title.drawAtPoint(l1, withAttributes: attr)
        
        if(firstDate != nil && lastDate != nil) {
            let dateFormatter = NSDateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd"
            let date1 = dateFormatter.stringFromDate(self.firstDate!)
            let date2 = dateFormatter.stringFromDate(self.lastDate!)
            let datesString = "Period: \(date1) - \(date2)"
            let l2 = CGPointMake(l1.x, l1.y + LINE_HEIGHT)
            datesString.drawAtPoint(l2, withAttributes: attr)
        }
        
        let distanceKm = String(format: "%0.2f", self.totalDistance!/1000)
        let distance = "Total distance: \(distanceKm) Km"
        let l3 = CGPointMake(l1.x, l1.y + LINE_HEIGHT*2)
        distance.drawAtPoint(l3, withAttributes: attr)
        
        let durationHours = String(format: "%02d", self.totalDuration!/3600)
        let durationMinutes = String(format: "%02d", (self.totalDuration! % 3600) / 60)
        let duration = "Total duration: \(durationHours):\(durationMinutes) hours"
        let l4 = CGPointMake(l1.x, l3.y + LINE_HEIGHT)
        duration.drawAtPoint(l4, withAttributes: attr)
        
        CGContextRestoreGState(context)
    }
    
    func drawElevationLegend(context: CGContext?) {
        
        guard athlete != nil else {
            return
        }
        
        let maxElevationMeters = self.maxElevationMetersRounded
        
        let font = UIFont.systemFontOfSize(14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.blackColor()]
        
        CGContextSaveGState(context)
        
        // compute elevations
        
        var elevations : [Int] = []
        for elevation in 0.stride(through: maxElevationMeters, by: 100) {
//        for(var elevation = 0; elevation <= maxElevationMeters; elevation += 100) {
            elevations.append(elevation)
        }
        elevations = elevations.reverse()
        
        // frame
        
        /*
        p0---p1
        |    |
        p3---p2
        */
        
        let LINE_HEIGHT = 12
        let p0 = CGPointMake(CGFloat(LEFT_SCALE_WIDTH + 10.0), 100)
        let p2 = CGPointMake(p0.x + 90, p0.y + 30 + CGFloat(elevations.count * LINE_HEIGHT))
        
        let titleFrame = CGRectMake(p0.x, p0.y, p2.x - p0.x, p2.y - p0.y)
        CGContextFillRect(context, titleFrame)
        CGContextStrokeRectWithWidth(context, titleFrame, 1.0)
        
        let p = CGPointMake(p0.x + 10, p0.y + 5)
        "Elevation".drawAtPoint(p, withAttributes: attr)
        
        for elevation in elevations {
            let x = CGFloat(p.x + 5)
            let y = Double(p.y) + 25 + Double(maxElevationMeters - elevation) / 100.0 * Double(LINE_HEIGHT)
            
            let elevationColor : UIColor = colorForElevationGain(Double(elevation))
            
            CGContextSetStrokeColorWithColor(context, UIColor.blackColor().CGColor)
            CGContextSetFillColorWithColor(context, elevationColor.CGColor)
            CGContextSetLineWidth(context, 0.5)
            
            CGContextAddEllipseInRect(context, CGRectMake(
                CGFloat(x - CGFloat(ACTIVITY_RADIUS)),
                CGFloat(y - Double(ACTIVITY_RADIUS)),
                CGFloat(ACTIVITY_RADIUS) * 2,
                CGFloat(ACTIVITY_RADIUS) * 2))
            
            CGContextDrawPath(context, .FillStroke);
            
            if(elevation == maxElevationMeters) {
                let s = "+\(elevation) m"
                let p = CGPointMake(x + CGFloat(10.0), CGFloat(y) - 10.0)
                s.drawAtPoint(p, withAttributes: attr)
            }
        }
        
        CGContextRestoreGState(context)
    }
    
    func drawLegendWithActivityDetails(context: CGContext?, activity: Activity) {
        
        let font = UIFont.systemFontOfSize(14)
        let attr = [NSFontAttributeName:font, NSForegroundColorAttributeName:UIColor.blackColor()]
        
        let dateFormatter = NSDateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm"
        
        CGContextSaveGState(context)
        
        // frame
        
        let p2 = CGPointMake(CGFloat(self.frame.size.width - 10), CGFloat(self.frame.size.height) - CGFloat(BOTTOM_SCALE_HEIGHT) - 10)
        let p0 = CGPointMake(p2.x - 400, p2.y - 45)
        
        let titleFrame = CGRectMake(p0.x, p0.y, p2.x - p0.x, p2.y - p0.y)
        CGContextFillRect(context, titleFrame)
        CGContextStrokeRectWithWidth(context, titleFrame, 1.0)
        
        // labels
        
        let LINE_HEIGHT : CGFloat = 18
        
        let l1 = CGPointMake(p0.x + 10, p0.y + 5)
        let prettyDate = dateFormatter.stringFromDate(activity.date)
        
        var dateAndPlace = "\(prettyDate)"
        if let city = activity.locationCity {
            dateAndPlace.appendContentsOf(", \(city)")
        }
        dateAndPlace.drawAtPoint(l1, withAttributes: attr)
        let l2 =  CGPointMake(l1.x, l1.y + LINE_HEIGHT)
        activity.name.drawAtPoint(l2, withAttributes: attr)
        
        CGContextRestoreGState(context)
    }
    
    func drawInImageContext() -> UIImage {
        UIGraphicsBeginImageContextWithOptions(self.frame.size, false, UIScreen.mainScreen().scale)
        guard let context = UIGraphicsGetCurrentContext() as CGContextRef? else { fatalError() }
        drawInContext(context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    func setupGlobalStatsFromActivities(activities: [Activity]) {
        self.maxElevationMetersRounded = self.maxElevationMetersRounded(activities)
        self.totalDistance = activities.reduce(0) { $0! + $1.meters}
        self.totalDuration = activities.reduce(0) { $0! + $1.seconds}
        
        self.firstDate = activities.first?.date
        self.lastDate = activities.last?.date
    }
    
    func setData(athlete: Athlete, activities: [Activity]) {
        self.athlete = athlete
        self.activities = activities
        self.setupGlobalStatsFromActivities(activities)
        self.setNeedsDisplay()
    }

    func setProgressiveData(athlete: Athlete, activities: [Activity]) {
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

