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
    
    static let sharedInstance = OSCManager()
    weak var delegate:OSCManagerDelegate?
    
    var server:OSCServer!
    var client:OSCClient!
    var clientPath = "udp://localhost:1234"
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
    var newHeelDetected = false
    var newToeDetected = false
    
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
        var timestamp = Int(round(NSDate().timeIntervalSince1970*1000))
        var foot = ""
        var address = ""
        var debug = ""
        let uuid = orphe.uuid!
        if ((uuid.uuidString == self.FIRST_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID)) {
            address =  "/real"
            debug += "REAL player "
            
        } else if ((orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID)) {
            address =  "/partner"
            debug += "PARTNER player "
        }
        
        if orphe.side == .left{
            //address += "/L"
            foot = "L"
            debug += "with LEFT foot "
        }
        else{
            //address += "/R"
            foot = "R"
            debug += "with RIGHT foot "
        }
        address += "/gesture"
        var arguments = [Any]()
        debug += "performed "
        let kind = gesture.getGestureKind()
        switch kind {
        case .STEP_TOE:
            arguments.append("STEP")
            arguments.append("TOE")
            if(self.lastDetectedToe == 0){
                self.lastDetectedToe = timestamp
            } else {
                let difference_between_taps = timestamp - self.lastDetectedToe
                // Detect a double toe if the timestamps between two toe gestures is max 800 ms.
                if (difference_between_taps <= 800) {
                    // Timestamp of double toe is the medium of the two detected timestamps.
                    self.lastDetectedToe = (self.lastDetectedToe + timestamp) / 2
                    timestamp = self.lastDetectedToe
                    self.newToeDetected = true
                } else {
                    self.newToeDetected = false
                    self.lastDetectedToe = timestamp
                    // Check async. if a double toe happens 0.8 seconds later.
                    let checkingDHQueue = DispatchQueue(label: "checkingGHQueue", attributes: .concurrent)
                    checkingDHQueue.async {
                        usleep(810000) //will sleep for .81 seconds
                        if (self.newToeDetected) {
                            debug += "DOUBLE TOE gesture "
                            address += foot + "/DT"
                            address += "/\(timestamp)"
                            arguments.append(gesture.getPower())
                            let message = OSCMessage(address: address, arguments: arguments)
                            self.client.send(message, to: self.clientPath)
                            print(debug)
                        } else {
                            debug += "NORMAL TOE gesture "
                            address += foot + "/T"
                            address += "/\(timestamp)"
                            arguments.append(gesture.getPower())
                            let message = OSCMessage(address: address, arguments: arguments)
                            self.client.send(message, to: self.clientPath)
                            print(debug)
                        }
                    }
                }
            }
        case .STEP_HEEL:
            arguments.append("STEP")
            arguments.append("HEEL")
            if(self.lastDetectedHeel == 0){
                self.lastDetectedHeel = timestamp
            } else {
                let difference_between_taps = timestamp - self.lastDetectedHeel
                // Detect a double heel if the timestamps between two heel gestures is max 800 ms.
                if (difference_between_taps <= 800) {
                    // Timestamp of double heel is the medium of the two detected timestamps.
                    self.lastDetectedHeel = (self.lastDetectedHeel + timestamp) / 2
                    timestamp = self.lastDetectedHeel
                    self.newHeelDetected = true
                } else {
                    self.newHeelDetected = false
                    self.lastDetectedHeel = timestamp
                    // Check async. if a double heel happens 0.8 seconds later.
                    let checkingDHQueue = DispatchQueue(label: "checkingGHQueue", attributes: .concurrent)
                    checkingDHQueue.async {
                        usleep(810000) //will sleep for .81 seconds
                        if (self.newHeelDetected) {
                            debug += "DOUBLE HEEL gesture "
                            address += foot + "/DH"
                            address += "/\(timestamp)"
                            arguments.append(gesture.getPower())
                            let message = OSCMessage(address: address, arguments: arguments)
                            self.client.send(message, to: self.clientPath)
                            print(debug)
                        } else {
                            debug += "NORMAL HEEL gesture "
                            address += foot + "/H"
                            address += "/\(timestamp)"
                            arguments.append(gesture.getPower())
                            let message = OSCMessage(address: address, arguments: arguments)
                            self.client.send(message, to: self.clientPath)
                            print(debug)
                        }
                    }
                }
            }
        default:
            break
        }
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
