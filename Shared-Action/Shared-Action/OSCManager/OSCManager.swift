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
    // Real player: White shoes, Partner player: Black shoes
    let FIRST_PLAYER_LEFT_UUID = "DF88A432-0317-4524-8479-CB84AAB5C9A1"
    let FIRST_PLAYER_RIGHT_UUID = "A0A2DB4C-F967-41AF-B4C4-44229AE535F3"
    let SECOND_PLAYER_LEFT_UUID = "2FF443A0-FFF9-4317-8C7F-30321B14B779"
    let SECOND_PLAYER_RIGHT_UUID = "7E186EAA-6E8E-40F2-B91D-C0E92D830254"
    let sequence = ["T","H","H","T", "H", "T", "H", "H","T","T"]
    
    static let sharedInstance = OSCManager()
    weak var delegate:OSCManagerDelegate?
    
    var server:OSCServer!
    var client:OSCClient!
    var clientPath = "udp://192.168.1.145:3000"
    //var clientPath_Right = "http://192.168.1.145:1234"
    var clientPath_Right = "http://192.168.11.11:1234"
    var address = ""
    var clientHost = "localhost" {
        didSet{
            clientPath = "udp://" + clientHost + ":" + String(clientPort)
        }
    }
    var clientPort = 1234 {
        didSet{
            clientPath = "udp://" + clientHost + ":" + String(clientPort)
        }
    }
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
    //TODO: Sometimes STEP_FLAT shows also STEP_HEEL and may interfere. Take care server-side if performed out of tune => don't blink rainbow! Maybe check power ?!
    func sendGesture(orphe:ORPData, gesture:ORPGestureEventArgs){
        let kin = gesture.getGestureKind()
        //print("\(kin.rawValue) detected")
        var timestamp = Int(round(NSDate().timeIntervalSince1970*1000))
        var foot = ""
        var debug = ""
        let uuid = orphe.uuid!
        var ad = ""
        if ((uuid.uuidString == self.FIRST_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID)) {
            ad =  "/real"
            debug += "REAL player "
            return
            
        } else if ((orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID)) {
            ad =  "/partner"
            debug += "PARTNER player "
            //return
        }
        ad  += "/gesture"
        if orphe.side == .left{
            //address += "/L"
            foot = "/L"
            debug += "with LEFT foot "
        }
        else{
            //address += "/R"
            foot = "/R"
            debug += "with RIGHT foot "
            
        }
        
        var difference_between_taps = timestamp - self.lastDetectedToe
        //print(difference_between_taps)
        
        //Make sure to not get rid of H after T if T_H error state
        if (kin.rawValue != 3 || self.lastDetectedGesture.0 != 1) {
            if (difference_between_taps <= 215) {
                print("Too fast")
                ad += "/FAST"
                self.sendHTTPMessage(ad: ad)
                return
            }
            
            difference_between_taps = timestamp - self.lastDetectedHeel
            //print(difference_between_taps)

            if (difference_between_taps <= 215) {
                print("Too fast")
                ad += "/FAST"
                self.sendHTTPMessage(ad: ad)
                return
            }
        }
        
        var arguments = [Any]()
        debug += "performed "
        let kind = gesture.getGestureKind()
        
        switch kind {
        case .STEP_FLAT:
            print("FLAT detected.")
        case .STEP_TOE:
           
            self.lastDetectedGesture = (1,timestamp)
            
            arguments.append("STEP")
            arguments.append("TOE")
            
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
                        debug += "DOUBLE TOE gesture "
                        ad += foot + "DT"
                        ad += "/\(timestamp)"
                        arguments.append(gesture.getPower())
                        let message = OSCMessage(address: ad, arguments: arguments)
                        self.sendHTTPMessage(ad: ad)
                        //self.client.send(message, to: self.clientPath)
                        //print(debug)
                        
                        print("DT")
                        print("")
                    } else {
                        let difference_between_toe_heel = timestamp - self.lastDetectedGesture.1
                           // print(difference_between_toe_heel)
                            //print(self.lastDetectedGesture.0)
                            if (self.lastDetectedGesture.0 == 0 && difference_between_toe_heel <= 800){
                                // error toe-heel detected => IGNORE first TOE
                                print("TOE-HEEL error")
                                return
                            }
                        
                        debug += "NORMAL TOE gesture "
                        ad += foot + "T"
                        ad += "/\(timestamp)"
                        arguments.append(gesture.getPower())
                        let message = OSCMessage(address: ad, arguments: arguments)
                        self.sendHTTPMessage(ad: ad)
                        //self.client.send(message, to: self.clientPath)
                        //print(debug)
                        
                        print("T")
                        print("")
                    }
            //    }
                }
            }
        case .STEP_HEEL:
            arguments.append("STEP")
            arguments.append("HEEL")
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
                        debug += "DOUBLE HEEL gesture "
                        ad += foot + "DH"
                        ad += "/\(timestamp)"
                        arguments.append(gesture.getPower())
                        let message = OSCMessage(address: ad, arguments: arguments)
                        self.sendHTTPMessage(ad: ad)
                        //self.client.send(message, to: self.clientPath)
                        //print(debug)
                        
                        print("DH")
                        print("")
                    } else {
                        debug += "NORMAL HEEL gesture "
                        ad += foot + "H"
                        ad += "/\(timestamp)"
                        arguments.append(gesture.getPower())
                        //let message = OSCMessage(address: ad, arguments: arguments)
                        self.sendHTTPMessage(ad: ad)
                        //self.client.send(message, to: self.clientPath)
                        //print(debug)
                       
                        print("H")
                        print("")
                    }
                }
              //  }
            }
        default:
            break
        }
    }
    
    func sendHTTPMessage(ad: String){
        let url = URL(string: "\(self.clientPath_Right)\(ad)")
        //print(url?.absoluteString as String!)
        /* let task = URLSession.shared.dataTask(with: url!) {(data, response, error) in
         guard error == nil else {
         print("ERROR : \(error!)")
         return
         }
         do {print("Message: \(ad) was sent")}
         }
         task.resume()*/
        //self.address = ""
    }
    
    /* CURRENTLY NOT NEEDED
     This method handles incoming requests from the server. The server message needs adhere to following naming constraints. There is only the left shoe for the first player and only the right shoe for the second player.
     Examples: localhost:1111/firstPlayer/LEFT/gesture/correct
     localhost:1111/secondPlayer/RIGHT/gesture/correct
     Testing: oscurl localhost:1111 /secondPlayer/RIGHT/gesture/correct test
     */
    func handle(_ message: OSCMessage!) {
        let oscAddress = message.address.components(separatedBy: "/")
        
        var side = ORPSide.left
        if oscAddress[2] == "RIGHT" {
            side = .right
        }
        var uuidString = ""
        if ( oscAddress[1] == "real" && side == ORPSide.left) {
            uuidString = self.FIRST_PLAYER_LEFT_UUID
        } else if (oscAddress[1] == "real" && side == ORPSide.right) {
            uuidString = self.FIRST_PLAYER_RIGHT_UUID
        } else if (oscAddress[1] == "partner" && side == ORPSide.left) {
            uuidString = self.SECOND_PLAYER_LEFT_UUID
        } else if (oscAddress[1] == "partner" && side == ORPSide.right) {
            uuidString = self.SECOND_PLAYER_RIGHT_UUID
        }
        guard let uuid = UUID(uuidString: uuidString) else {
            print("Shoes may not be connected. Please check!")
            return
        }
        
        let orphe = ORPManager.sharedInstance.getOrpheData(uuid: uuid)!
        var isNoCommand = false
        var mString = ""
        
        switch oscAddress[4] {
        case "correct":
            mString = "Correct gesture detected! RAINBOWWWW "
            orphe.triggerLight(lightNum: 9)
            orphe.triggerLight(lightNum: 9)
        default:
            isNoCommand = true
            break
        }
        
        var args = ""
        if isNoCommand {
            mString = "No such command."
        }
        else {
            for arg in message.arguments{
                args +=  " " + String(describing: arg)
            }
            mString = message.address + args
        }
        delegate?.oscDidReceiveMessage?(message: mString)
    }
    
    //MARK: - Notifications
    @objc func OrpheDidCatchGestureEvent(notification:Notification){
        guard let userInfo = notification.userInfo else {return}
        let gestureEvent = userInfo[OrpheGestureUserInfoKey] as! ORPGestureEventArgs
        let orphe = userInfo[OrpheDataUserInfoKey] as! ORPData
        sendGesture(orphe: orphe, gesture: gestureEvent)
    }
}

