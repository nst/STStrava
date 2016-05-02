//
//  STActivities.swift
//  STStrava
//
//  Created by nst on 12/11/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

import Foundation

let USE_LOCAL_FILES : Bool = false

public enum Result<T> {
    case Failure(NSError)
    case Success(T)
}

func dateFromString(dateString: String?) -> NSDate? {
    guard let existringDateString = dateString else { return nil }
    let dateFormatter = NSDateFormatter()
    dateFormatter.locale = NSLocale(localeIdentifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
    return dateFormatter.dateFromString(existringDateString)
}

public struct Athlete {
    let id: Int
    let username: String?
    let firstname: String?
    let lastname: String?
    let profileMedium: String?
    
    init?(fromAthleteDictionary d: NSDictionary?) {
        
        guard let d = d else { return nil }
        guard let id = d["id"] as? Int else { return nil }
        
        self.id = id
        
        username = d["username"] as? String
        firstname = d["firstname"] as? String
        lastname = d["lastname"] as? String
        profileMedium = d["profile_medium"] as? String // TODO: show image
    }
}

public struct Activity {
    let id: Int
    let date: NSDate
    let meters: Double
    let seconds: Int
    let elevationGain: Double
    let name: String
    let type: String
    let locationCity: String?
    let startDateLocale: NSDate?
    let athlete: Athlete?
    
    init?(fromActivityDictionary d: NSDictionary?) {
        
        guard let d = d else { return nil }
        
        guard
            let id = d["id"] as? Int,
            let date = dateFromString(d["start_date"] as? String),
            let meters = d["distance"] as? Double,
            let seconds = d["elapsed_time"] as? Int,
            let elevationGain = d["total_elevation_gain"] as? Double,
            let name = d["name"] as? String,
            let type = d["type"] as? String,
            let startDateLocale = dateFromString(d["start_date_local"] as? String),
            let athlete = Athlete(fromAthleteDictionary: d["athlete"] as? NSDictionary)
            else { return nil }
        
        self.id = id
        self.date = date
        self.meters = meters
        self.seconds = seconds
        self.elevationGain = elevationGain
        self.name = name
        self.type = type
        self.locationCity = d["location_city"] as? String
        self.startDateLocale = startDateLocale
        self.athlete = athlete
    }
}

public class StravaAPI {
    
    public enum StravaAPI : ErrorType {
        case BadURL(urlString: String)
        case BadHTTPStatus(status: Int)
        case BadJSON
        case NoData
        case StravaErrors(errors: AnyObject?)
        case GenericError
    }
    
    private var clientID : String
    private var clientSecret : String
    private(set) var accessToken : String?
    
    // find clientID and clientSecret on https://www.strava.com/settings/api
    public required init(clientID: String, clientSecret: String, storedAccessToken: String?) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.accessToken = storedAccessToken
        
        NSNotificationCenter.defaultCenter().addObserverForName("CodeWasReceived", object: nil, queue: nil) { [unowned self] (notification) -> Void in
            guard let existingCode = notification.userInfo?["code"] as? String else { return }
            
            self.fetchAccessToken(clientID, clientSecret: clientSecret, code: existingCode) { [unowned self] (result) -> () in
                switch result {
                case let .Success(receivedAccessToken):
                    guard let nonOptAccessToken : String = receivedAccessToken else { return }
                    self.accessToken = nonOptAccessToken
                    print("-- accessToken", nonOptAccessToken)
                    NSNotificationCenter.defaultCenter().postNotificationName("StravaAPIHasAccessToken", object: nil, userInfo: ["accessToken":nonOptAccessToken])
                case let .Failure(error):
                    print(error)
                }
            }
        }
    }
    
    public convenience init(clientID: String, clientSecret: String) {
        self.init(clientID: clientID, clientSecret: clientSecret, storedAccessToken: nil)
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: "CodeWasReceived", object: nil)
    }
    
    public func fetchAthlete(completionHandler: (Result<Athlete>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/athlete" + accessTokenURLSuffix()
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        request.dr2_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, d) = try $0()
                if let errors = d["errors"] {
                    let e = NSError(domain: "STStrava", code: StravaAPI.BadJSON._code, userInfo: [NSLocalizedDescriptionKey:String(errors)])
                    completionHandler(.Failure(e))
                    return
                }
                
                if let athlete = Athlete(fromAthleteDictionary: d) {
                    completionHandler(.Success(athlete))
                } else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.BadJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionHandler(.Failure(e))
                }
            } catch let e as NSError {
                completionHandler(.Failure(e))
            }
        }
    }
    
    public func fetchActivities(completionHandler: (Result<[Activity]>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities" + accessTokenURLSuffix() + "&per_page=200"
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
            do {
                let (_, a) = try $0()
                let runActivities = self.sortedRunActivitiesFromJSONArray(a)
                completionHandler(.Success(runActivities))
            } catch let DRError.Error(r, nsError) {
                
                // try to read a Strava error
                
                if let data = r.data,
                    d = try? NSJSONSerialization.JSONObjectWithData(data, options: []),
                    message = d["message"] as? String,
                    errors = d["errors"] as? [[String:AnyObject]] {
                    print("-- ", d)
                
                    // build a custom NSError
                    let userInfo = [NSLocalizedDescriptionKey:"\(message) - \(errors)"]
                    let e = NSError(domain: "Strava", code: 0, userInfo: userInfo)
                    completionHandler(.Failure(e))
                    return
                }
                
                completionHandler(.Failure(nsError))
            } catch {
                assertionFailure()
            }
        }
    }
    
    public func hasAccessToken() -> Bool {
        return self.accessToken != nil
    }
    
    public func forgetAccessToken() {
        self.accessToken = nil
    }
    
    public func startAuthorizationProcess(redirectURI redirectURI: String) {
        
        let urlString = "https://www.strava.com/oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&approval_prompt=force"
        let url = NSURL(string: urlString)
        
        if let existingURL = url {
            // notification instead of direct opening so that this class doesn't depend on UIKit
            NSNotificationCenter.defaultCenter().postNotificationName("OpenURL", object: nil, userInfo: ["URL":existingURL])
        }
    }
    
    private func fetchAccessToken(clientID: String, clientSecret: String, code: String, completionBlock:(Result<String>) -> ()) {
        
        /*
        curl -X POST https://www.strava.com/oauth/token \
        -F client_id=111 \
        -F client_secret=222 \
        -F code=333
        */
        
        let url = NSURL(string: "https://www.strava.com/oauth/token")!
        let request = NSMutableURLRequest(URL: url)
        request.HTTPMethod = "POST"
        let body = "client_id=\(clientID)&client_secret=\(clientSecret)&code=\(code)"
        request.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding);
        
        request.dr2_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, d) = try $0()

                guard let receivedExistingAccessToken = d["access_token"] as? String else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.BadJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionBlock(.Failure(e))
                    return
                }
                completionBlock(.Success(receivedExistingAccessToken))
            } catch let e as NSError {
                completionBlock(.Failure(e))
            }
        }
    }
    
    private func accessTokenURLSuffix() -> String {
        if let existingAccessToken = self.accessToken {
            return "?access_token=" + existingAccessToken
        }
        return ""
    }
    
    private func sortedRunActivitiesFromJSONArray(a:NSArray) -> [Activity] {
        return a
            .flatMap( { $0 as? NSDictionary })
            .flatMap( { Activity(fromActivityDictionary:$0) })
            .filter{ $0.type == "Run" }
            .sort({ $0.date.compare($1.date) == NSComparisonResult.OrderedAscending })
    }
    
    public func fetchFriendsActivities(athleteID: Int, completionHandler: (Result<[Activity]>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities/following" + accessTokenURLSuffix()
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
            do {
                let (_, a) = try $0()
                let runActivitiesFromSpecificFriend = self.sortedRunActivitiesFromJSONArray(a).filter{ $0.athlete?.id == athleteID }
                completionHandler(.Success(runActivitiesFromSpecificFriend))
            } catch let e as NSError {
                completionHandler(.Failure(e))
            }
        }
    }
    
    private func fetchActivity(activityID: String, completionHandler: (Result<Activity>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities/\(activityID)" + accessTokenURLSuffix()
        let url = NSURL(string: urlString)
        let request = NSURLRequest(URL: url!)
        
        request.dr2_fetchTypedJSON(NSDictionary.self) {
            do {
                let (_, d) = try $0()
                
                if let activity = Activity(fromActivityDictionary: d) {
                    completionHandler(.Success(activity))
                } else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.BadJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionHandler(.Failure(e))
                }
                
            } catch let e as NSError {
                completionHandler(.Failure(e))
            }
        }
    }
    
    private func maxElevationGain(shortActivities:[Activity]) -> NSNumber {
        return shortActivities.minElement({ $0.elevationGain > $1.elevationGain })!.elevationGain
    }
    
    private func maxMeters(shortActivities:[Activity]) -> NSNumber {
        return shortActivities.minElement({ $0.meters > $1.meters })!.meters
    }
    
    private func maxSeconds(shortActivities:[Activity]) -> NSNumber {
        return shortActivities.minElement({ $0.seconds > $1.seconds })!.seconds
    }
}
