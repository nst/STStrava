//
//  STAnimatedGifCreator.swift
//  STStrava
//
//  Created by nst on 21/11/15.
//  Copyright © 2015 Nicolas Seriot. All rights reserved.
//

import UIKit
import ImageIO
import MobileCoreServices

open class STAnimatedGIFCreator {
    
    let imageDestination : CGImageDestination?
    
    init?(destinationPath: String?, loop: Bool) {
        
        guard let existingPath = destinationPath else {
            return nil
        }
        
        imageDestination = CGImageDestinationCreateWithURL(
            URL(fileURLWithPath: existingPath) as CFURL,
            kUTTypeGIF,
            0,
            nil)
        
        guard imageDestination != nil else { return nil }
        
        let loopCount = loop ? 0 : 1
        let gifProperties = [ kCGImagePropertyGIFDictionary as String : [kCGImagePropertyGIFLoopCount as String:loopCount] ]
        
        CGImageDestinationSetProperties(imageDestination!, gifProperties as CFDictionary?)
    }
    
    func addImage(_ image : UIImage, duration : Double) {
        let frameProperties : Dictionary = [ kCGImagePropertyGIFDictionary as String : [kCGImagePropertyGIFDelayTime as String:duration] ]
        CGImageDestinationAddImage(imageDestination!, image.cgImage!, frameProperties as CFDictionary?)
    }
    
    func writeFile() -> Bool {
        return CGImageDestinationFinalize(imageDestination!)
    }
    
}
