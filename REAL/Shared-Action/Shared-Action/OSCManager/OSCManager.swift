//
//  OSCManager.swift
//  Shared-Action
//
//  Created by Marla Na on 09.06.18.
//  Copyright © 2018 Marla Na. All rights reserved.
//

import Orphe
import OSCKit

@objc public protocol OSCManagerDelegate : NSObjectProtocol {
    @objc optional func oscDidReceiveMessage(message:String)
}

class OSCManager:NSObject, OSCServerDelegate{
    
    //MARK: UUID Orphe Data
    static let sharedInstance = OSCManager()
    weak var delegate:OSCManagerDelegate?
    var server:OSCServer!
    var client:OSCClient!
    var clientPath = "http://192.168.1.145:1234"
    var address = ""
    var serverPort = 1111
    // Save the last detected heel in order to detect double heels.
    var lastDetectedHeel = 0
    var lastDetectedToe = 0
    var firstHeelForDoubleDetected = false
    var firstToeForDoubleDetected = false
    // (0 for Heel, 1 for Toe, Timestamp)
    var lastDetectedGesture = (0,0)
    
    private override init() {
        super.init()
        server = OSCServer()
        server.delegate = self
        
        client = OSCClient()
        let _ = self.startReceive()
        
        NotificationCenter.default.addObserver(self, selector:  #selector(OSCManager.OrpheDidCatchGestureEvent(notification:)), name: .OrpheDidCatchGestureEvent, object: nil)
        
    }
    
    func stopReceive(){
        server.stop()
    }
    
    func startReceive()->Bool{
        do {
            try execute {
                self.server.listen(self.serverPort)
            }
        } catch _ {
            return false
        }
        return true
    }
    
    func execute(_ tryBlock: () -> ()) throws {
        try ObjC_Exception.catch(try: tryBlock)
    }
    
    /* This method detectes gestures from Orphe and sends following information to the game server:
     player: firstPlayer or secondPlayer, shoe: L or R, name of gesture: T or H or DH, timestamp in milliseconds.
     Example: localhost:1234/real/gesture/LH/timestamp(milliseconds)
     */
    func sendGesture(orphe:ORPData, gesture:ORPGestureEventArgs){
        print("gesture detected")
        let gestureKind = gesture.getGestureKind()
        var timestamp = Int(round(NSDate().timeIntervalSince1970*1000))
        var message = "/real/gesture"
        
        var difference_between_taps = timestamp - self.lastDetectedToe
        //Make sure to not get rid of H after T if T_H error state
        if (gestureKind.rawValue != 3 || self.lastDetectedGesture.0 != 1) {
            if (difference_between_taps <= 215) {
                message += "/F/\(timestamp)"
                print(message)
                self.sendHTTPMessage(ad: message)
                return
            }
            difference_between_taps = timestamp - self.lastDetectedHeel
            if (difference_between_taps <= 215) {
                message += "/F/\(timestamp)"
                print(message)
                self.sendHTTPMessage(ad: message)
                return
            }
        }
        if orphe.side == .left{
            message += "/L"
        }
        else{
            message += "/R"
        }
        
        var arguments = [Any]()
        
        switch gestureKind {
        case .STEP_FLAT:
            print("FLAT detected.")
        case .STEP_TOE:
            self.lastDetectedGesture = (1,timestamp)
            let difference_between_taps = timestamp - self.lastDetectedToe
            // Detect a double toe if the timestamps between two toe gestures is max 800 ms.
            if (difference_between_taps <= 800) {
                // Timestamp of double toe is the medium of the two detected timestamps.
                self.lastDetectedToe = (self.lastDetectedToe + timestamp) / 2
                timestamp = self.lastDetectedToe
                self.firstToeForDoubleDetected = true
            } else {
                self.firstToeForDoubleDetected = false
                self.lastDetectedToe = timestamp
                // Check async. if a double toe happens 0.8 seconds later.
                let checkingDHQueue = DispatchQueue(label: "checkingGHQueue", attributes: .concurrent)
                checkingDHQueue.async {
                    usleep(810000) //will sleep for .81 seconds
                    if (self.firstToeForDoubleDetected) {
                        message += "DT"
                        message += "/\(timestamp)"
                        self.sendHTTPMessage(ad: message)
                        print("")
                    } else {
                        let difference_between_toe_heel = timestamp - self.lastDetectedGesture.1
                        if (self.lastDetectedGesture.0 == 0 && difference_between_toe_heel <= 800){
                            // error toe-heel detected => IGNORE first TOE
                            print("TOE-HEEL error")
                            return
                        }
                        message += "T"
                        message += "/\(timestamp)"
                        self.sendHTTPMessage(ad: message)
                        print("")
                    }
                }
            }
        case .STEP_HEEL:
            self.lastDetectedGesture = (0,timestamp)
            let difference_between_taps = timestamp - self.lastDetectedHeel
            // Detect a double heel if the timestamps between two heel gestures is max 800 ms.
            if (difference_between_taps <= 800) {
                // Timestamp of double heel is the medium of the two detected timestamps.
                self.lastDetectedHeel = (self.lastDetectedHeel + timestamp) / 2
                timestamp = self.lastDetectedHeel
                self.firstHeelForDoubleDetected = true
            } else {
                self.firstHeelForDoubleDetected = false
                self.lastDetectedHeel = timestamp
                // Check async. if a double heel happens 0.8 seconds later.
                let checkingDHQueue = DispatchQueue(label: "checkingGHQueue", attributes: .concurrent)
                checkingDHQueue.async {
                    usleep(810000) //will sleep for .81 seconds
                    if (self.firstHeelForDoubleDetected) {
                        message += "DH"
                        message += "/\(timestamp)"
                        self.sendHTTPMessage(ad: message)
                        print("")
                    } else {
                        message += "H"
                        message += "/\(timestamp)"
                        arguments.append(gesture.getPower())
                        self.sendHTTPMessage(ad: message)
                        print("")
                    }
                }
            }
        default:
            break
        }
    }
    
    func sendHTTPMessage(ad: String){
        let url = URL(string: "\(self.clientPath)\(ad)")
        print(url?.absoluteString as String!)
        let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
            guard error == nil else {
                print("ERROR : \(error!)")
                return
            }
            do {print("Message: \(ad) was sent")}
        }
        task.resume()
        self.address = ""
    }
    
    /* CURRENTLY NOT NEEDED */
    func handle(_ message: OSCMessage!) {
    }
    
    //MARK: - Notifications
    @objc func OrpheDidCatchGestureEvent(notification:Notification){
        guard let userInfo = notification.userInfo else {return}
        let gestureEvent = userInfo[OrpheGestureUserInfoKey] as! ORPGestureEventArgs
        let orphe = userInfo[OrpheDataUserInfoKey] as! ORPData
        sendGesture(orphe: orphe, gesture: gestureEvent)
    }
}

