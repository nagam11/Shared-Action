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
    
    private override init() {
        super.init()
        server = OSCServer()
        server.delegate = self
        
        client = OSCClient()
        self.startReceive()
        
        NotificationCenter.default.addObserver(self, selector:  #selector(OSCManager.OrpheDidUpdateSensorData(notification:)), name: .OrpheDidUpdateSensorData, object: nil)
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
    
    func sendSensorValues(orphe:ORPData){
        var address = ""
        let uuid = orphe.uuid!
        if ((uuid.uuidString == self.FIRST_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID)) {
            address =  "/firstPlayer"
            
        } else if ((orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID)) {
             address =  "/secondPlayer"
        }
        
        if orphe.side == .left {            
            address +=  "/LEFT"
        }
        else{
            address += "/RIGHT"
        }
        address += "/sensorValues"
        var args = [Any]()
        args += orphe.getQuat() as [Any]
        args += orphe.getEuler() as [Any]
        args += orphe.getAcc() as [Any]
        args += orphe.getAccOfGravity() as [Any]
        args += orphe.getGyro() as [Any]
        args.append(orphe.getMag() as Any)
        args.append(orphe.getShock() as Any)
        let message = OSCMessage(address: address, arguments: args)
        client.send(message, to: clientPath)
    }
    
    func sendGesture(orphe:ORPData, gesture:ORPGestureEventArgs){
        //TODO: document FORMAT: localhost:1234/firstPlayer/LEFT/gesture/heel/timestamp(milliseconds)
        let timestamp = Int(round(NSDate().timeIntervalSince1970*1000))
        var address = ""
        let uuid = orphe.uuid!
        if ((uuid.uuidString == self.FIRST_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID)) {
            address =  "/firstPlayer"
            
        } else if ((orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) || (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID)) {
            address =  "/secondPlayer"
        }
        
        if orphe.side == .left{
            address += "/LEFT"
        }
        else{
            address += "/RIGHT"
        }
        address += "/gesture"
        var arguments = [Any]()
        //TODO: Add Double heel
        switch gesture.getGestureKind() {
        /*case .KICK:
            arguments.append("KICK")
            arguments.append("")
            address += "/kick" */
        case .STEP_TOE:
            arguments.append("STEP")
            arguments.append("TOE")
            address += "/toe"
        /*case .STEP_FLAT:
            arguments.append("STEP")
            arguments.append("FLAT")*/
        case .STEP_HEEL:
            arguments.append("STEP")
            arguments.append("HEEL")
            address += "/heel"
        default:
            break
        }
        
        address += "/\(timestamp)"
        arguments.append(gesture.getPower())
        let message = OSCMessage(address: address, arguments: arguments)
        client.send(message, to: clientPath)
    }
    
   func handle(_ message: OSCMessage!) {
    /* TODO: needed document FORMAT: localhost:1111/firstPlayer/LEFT/gesture/correct
     DEFINED : localhost:1111/firstPlayer/LEFT/gesture/correct
                localhost:1111/secondPlayer/RIGHT/gesture/correct
     TESTING: oscurl localhost:1111 /secondPlayer/RIGHT/gesture/correct test
     */
        let oscAddress = message.address.components(separatedBy: "/")
        
        var side = ORPSide.left
        if oscAddress[2] == "RIGHT" {
            side = .right
        }
        var uuidString = ""
        if ( oscAddress[1] == "firstPlayer" && side == ORPSide.left) {
            uuidString = self.FIRST_PLAYER_LEFT_UUID
        } else if (oscAddress[1] == "firstPlayer" && side == ORPSide.right) {
            uuidString = self.FIRST_PLAYER_RIGHT_UUID
        } else if (oscAddress[1] == "secondPlayer" && side == ORPSide.left) {
            uuidString = self.SECOND_PLAYER_LEFT_UUID
        } else if (oscAddress[1] == "secondPlayer" && side == ORPSide.right) {
            uuidString = self.SECOND_PLAYER_RIGHT_UUID
        }
        let uuid = UUID(uuidString: uuidString)
        //let orphes = ORPManager.sharedInstance.getOrpheArray(side: side)
        //TODO: Make sure they are connected !!
        let orphe = ORPManager.sharedInstance.getOrpheData(uuid: uuid!)!
        var isNoCommand = false
        var mString = ""
            
        switch oscAddress[4] {
        case "correct":       
            mString = "Correct gesture detected! "
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
    @objc func OrpheDidUpdateSensorData(notification:Notification){
        guard let userInfo = notification.userInfo else {return}
        let orphe = userInfo[OrpheDataUserInfoKey] as! ORPData
        sendSensorValues(orphe: orphe)
    }
    
    @objc func OrpheDidCatchGestureEvent(notification:Notification){
        guard let userInfo = notification.userInfo else {return}
        let gestureEvent = userInfo[OrpheGestureUserInfoKey] as! ORPGestureEventArgs
        let orphe = userInfo[OrpheDataUserInfoKey] as! ORPData
        sendGesture(orphe: orphe, gesture: gestureEvent)
    }
    
}
