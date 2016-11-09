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
    case failure(NSError)
    case success(T)
}

func dateFromString(_ dateString: String?) -> Date? {
    guard let existringDateString = dateString else { return nil }
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZ"
    return dateFormatter.date(from: existringDateString)
}

public struct Athlete {
    let id: Int
    let username: String?
    let firstname: String?
    let lastname: String?
    let profileMedium: String?
    
    init?(fromAthleteDictionary d: [String:AnyObject]?) {
        
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
    let date: Date
    let meters: Double
    let seconds: Int
    let elevationGain: Double
    let name: String
    let type: String
    let locationCity: String?
    let startDateLocale: Date?
    let athlete: Athlete?
    
    init?(fromActivityDictionary d: [String:AnyObject]?) {
        
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
            let athlete = Athlete(fromAthleteDictionary: d["athlete"] as? [String:AnyObject])
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

open class StravaAPI {
    
    public enum StravaAPI : Error {
        case badURL(urlString: String)
        case badHTTPStatus(status: Int)
        case badJSON
        case noData
        case stravaErrors(errors: AnyObject?)
        case genericError
    }
    
    fileprivate var clientID : String
    fileprivate var clientSecret : String
    fileprivate(set) var accessToken : String?
    
    // find clientID and clientSecret on https://www.strava.com/settings/api
    public required init(clientID: String, clientSecret: String, storedAccessToken: String?) {
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.accessToken = storedAccessToken
        
        NotificationCenter.default.addObserver(forName: NSNotification.Name(rawValue: "CodeWasReceived"), object: nil, queue: nil) { [unowned self] (notification) -> Void in
            guard let existingCode = (notification as NSNotification).userInfo?["code"] as? String else { return }
            
            self.fetchAccessToken(clientID, clientSecret: clientSecret, code: existingCode) { [unowned self] (result) -> () in
                switch result {
                case let .success(receivedAccessToken):
                    self.accessToken = receivedAccessToken
                    print("-- accessToken", receivedAccessToken)
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "StravaAPIHasAccessToken"), object: nil, userInfo: ["accessToken":receivedAccessToken])
                case let .failure(error):
                    print(error)
                }
            }
        }
    }
    
    public convenience init(clientID: String, clientSecret: String) {
        self.init(clientID: clientID, clientSecret: clientSecret, storedAccessToken: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name(rawValue: "CodeWasReceived"), object: nil)
    }
    
    open func fetchAthlete(_ completionHandler: @escaping (Result<Athlete>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/athlete" + accessTokenURLSuffix()
        let url = URL(string: urlString)
        let request = URLRequest(url: url!)
        
        request.dr2_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, d) = try $0()
                if let errors = d["errors"] {
                    let e = NSError(domain: "STStrava", code: StravaAPI.badJSON._code, userInfo: [NSLocalizedDescriptionKey:String(describing:errors)])
                    completionHandler(.failure(e))
                    return
                }
                
                if let athlete = Athlete(fromAthleteDictionary: d) {
                    completionHandler(.success(athlete))
                } else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.badJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionHandler(.failure(e))
                }
            } catch let e as NSError {
                completionHandler(.failure(e))
            }
        }
    }
    
    open func fetchActivities(_ completionHandler: @escaping (Result<[Activity]>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities" + accessTokenURLSuffix() + "&per_page=200"
        let url = URL(string: urlString)
        let request = URLRequest(url: url!)
        
        request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
            do {
                let (_, a) = try $0()
                let runActivities = self.sortedRunActivitiesFromJSONArray(a)
                completionHandler(.success(runActivities))
            } catch let DRError.error(r, nsError) {
                
                // try to read a Strava error
                
                if let data = r.data,
                let optDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String:AnyObject],
                    let d = optDict,
                    let message = d["message"] as? String,
                    let errors = d["errors"] as? [[String:AnyObject]] {
                    print("-- ", d)
                
                    // build a custom NSError
                    let userInfo = [NSLocalizedDescriptionKey:"\(message) - \(errors)"]
                    let e = NSError(domain: "Strava", code: 0, userInfo: userInfo)
                    completionHandler(.failure(e))
                    return
                }
                
                completionHandler(.failure(nsError))
            } catch {
                assertionFailure()
            }
        }
    }
    
    open func hasAccessToken() -> Bool {
        return self.accessToken != nil
    }
    
    open func forgetAccessToken() {
        self.accessToken = nil
    }
    
    open func startAuthorizationProcess(redirectURI: String) {
        
        let urlString = "https://www.strava.com/oauth/authorize?client_id=\(clientID)&response_type=code&redirect_uri=\(redirectURI)&approval_prompt=force"
        let url = URL(string: urlString)
        
        if let existingURL = url {
            // notification instead of direct opening so that this class doesn't depend on UIKit
            NotificationCenter.default.post(name: Notification.Name(rawValue: "OpenURL"), object: nil, userInfo: ["URL":existingURL])
        }
    }
    
    fileprivate func fetchAccessToken(_ clientID: String, clientSecret: String, code: String, completionBlock:@escaping (Result<String>) -> ()) {
        
        /*
        curl -X POST https://www.strava.com/oauth/token \
        -F client_id=111 \
        -F client_secret=222 \
        -F code=333
        */
        
        let url = URL(string: "https://www.strava.com/oauth/token")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let body = "client_id=\(clientID)&client_secret=\(clientSecret)&code=\(code)"
        request.httpBody = body.data(using: String.Encoding.utf8);
        
        request.dr2_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, d) = try $0()

                guard let receivedExistingAccessToken = d["access_token"] as? String else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.badJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionBlock(.failure(e))
                    return
                }
                completionBlock(.success(receivedExistingAccessToken))
            } catch let e as NSError {
                completionBlock(.failure(e))
            }
        }
    }
    
    fileprivate func accessTokenURLSuffix() -> String {
        if let existingAccessToken = self.accessToken {
            return "?access_token=" + existingAccessToken
        }
        return ""
    }
    
    fileprivate func sortedRunActivitiesFromJSONArray(_ a:[[String:AnyObject]]) -> [Activity] {
        return a
            .flatMap( { $0 })
            .flatMap( { Activity(fromActivityDictionary:$0) })
            .filter{ $0.type == "Run" }
            .sorted(by: { $0.date.compare($1.date) == ComparisonResult.orderedAscending })
    }
    
    open func fetchFriendsActivities(_ athleteID: Int, completionHandler: @escaping (Result<[Activity]>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities/following" + accessTokenURLSuffix()
        let url = URL(string: urlString)
        let request = URLRequest(url: url!)
        
        request.dr2_fetchTypedJSON([[String:AnyObject]].self) {
            do {
                let (_, a) = try $0()
                let runActivitiesFromSpecificFriend = self.sortedRunActivitiesFromJSONArray(a).filter{ $0.athlete?.id == athleteID }
                completionHandler(.success(runActivitiesFromSpecificFriend))
            } catch let e as NSError {
                completionHandler(.failure(e))
            }
        }
    }
    
    fileprivate func fetchActivity(_ activityID: String, completionHandler: @escaping (Result<Activity>) -> ()) {
        
        let urlString = "https://www.strava.com/api/v3/activities/\(activityID)" + accessTokenURLSuffix()
        let url = URL(string: urlString)
        let request = URLRequest(url: url!)
        
        request.dr2_fetchTypedJSON([String:AnyObject].self) {
            do {
                let (_, d) = try $0()
                
                if let activity = Activity(fromActivityDictionary: d) {
                    completionHandler(.success(activity))
                } else {
                    let e = NSError(domain: "STStrava", code: StravaAPI.badJSON._code, userInfo: [NSLocalizedDescriptionKey:"Bad JSON"])
                    completionHandler(.failure(e))
                }
                
            } catch let e as NSError {
                completionHandler(.failure(e))
            }
        }
    }
    
    fileprivate func maxElevationGain(_ shortActivities:[Activity]) -> NSNumber {
        let x = shortActivities.min(by: { $0.elevationGain > $1.elevationGain })!.elevationGain
        return NSNumber(value:x)
    }
    
    fileprivate func maxMeters(_ shortActivities:[Activity]) -> NSNumber {
        let x = shortActivities.min(by: { $0.meters > $1.meters })!.meters
        return NSNumber(value:x)
    }
    
    fileprivate func maxSeconds(_ shortActivities:[Activity]) -> NSNumber {
        let x = shortActivities.min(by: { $0.seconds > $1.seconds })!.seconds
        return NSNumber(value:x)
    }
}
