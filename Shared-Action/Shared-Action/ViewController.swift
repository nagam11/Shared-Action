//
//  AppDelegate.swift
//  Shared-Action
//
//  Created by Marla Na on 09.06.18.
//  Copyright © 2018 Marla Na. All rights reserved.
//

import Cocoa
import Orphe
import OSCKit

class ViewController: NSViewController {
    
    // UUID ORPHE DATA
    let FIRST_PLAYER_LEFT_UUID = "A0A2DB4C-F967-41AF-B4C4-44229AE535F3"
    let FIRST_PLAYER_RIGHT_UUID = ""
    let SECOND_PLAYER_LEFT_UUID = ""
    let SECOND_PLAYER_RIGHT_UUID = ""
    
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var leftSensorLabel: NSTextField!
    @IBOutlet weak var rightSensorLabel: NSTextField!   
    @IBOutlet weak var firstPlayerLeft: NSTextField!
    @IBOutlet weak var firstPlayerRight: NSTextField!
    @IBOutlet weak var secondPlayerLeft: NSTextField!
    @IBOutlet weak var secondPlayerRight: NSTextField!
    @IBOutlet weak var gestureLabel: NSTextField!
    @IBOutlet weak var gestureDetectedLabel: NSTextField!
    var rssiTimer: Timer?

    var leftGesture = ""
    var rightGesture = ""
    var shoesConnected = false
    let gestures = ["Heel", "Toe", "Up"]
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.allowsTypeSelect = false
        
        ORPManager.sharedInstance.delegate = self
        ORPManager.sharedInstance.isEnableAutoReconnection = false
        ORPManager.sharedInstance.startScan()
        
        //rssiTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(ViewController.readRSSI), userInfo: nil, repeats: true)
        
        //OSC view
        OSCManager.sharedInstance.delegate = self
        print(OSCManager.sharedInstance.clientHost)
        print(String(OSCManager.sharedInstance.clientPort))
        print(String(OSCManager.sharedInstance.serverPort))
    }

    override var representedObject: Any? {
        didSet {
            
        }
    }
    
    func updateCellsState(){
        for (index, orp) in ORPManager.sharedInstance.availableORPDataArray.enumerated(){
            for (columnNum, _) in tableView.tableColumns.enumerated(){
                if let cell = tableView.view(atColumn: columnNum, row: index, makeIfNecessary: true) as? NSTableCellView{
                    if orp.state() == .connected{
                        cell.textField?.textColor = NSColor.yellow
                        cell.textField?.backgroundColor = NSColor.darkGray
                    }
                    else{
                        cell.textField?.textColor = NSColor.black
                        cell.textField?.backgroundColor = NSColor.white
                    }
                }
            }
            
        }
    }
    
    override func keyDown(with theEvent: NSEvent) {
        super.keyDown(with: theEvent)
        if let lightNum:UInt8 = UInt8(theEvent.characters!){
            for orp in ORPManager.sharedInstance.connectedORPDataArray{
                orp.triggerLight(lightNum: lightNum)
            }
        }
    }

}

extension  ViewController: NSTableViewDelegate{
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView?{
        let cellIdentifier: String = "NameCell"
        
        if let cell = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: cellIdentifier), owner: nil) as? NSTableCellView {
            if tableColumn == tableView.tableColumns[0] {
                cell.textField?.stringValue = ORPManager.sharedInstance.availableORPDataArray[row].name
                cell.textField?.drawsBackground = true
            }
            else if tableColumn == tableView.tableColumns[1] {
                cell.textField?.stringValue = "0"
                cell.textField?.drawsBackground = true
            }
            return cell
        }
        return nil
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        if tableView.selectedRow != -1 {
            let orp = ORPManager.sharedInstance.availableORPDataArray[tableView.selectedRow]
            if orp.state() == .disconnected{
                ORPManager.sharedInstance.connect(orphe: orp)
            }
            else{
                ORPManager.sharedInstance.disconnect(orphe: orp)
            }
        }
    }
    
}

extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ORPManager.sharedInstance.availableORPDataArray.count
    }
}

extension  ViewController: ORPManagerDelegate{
    
    //MARK: - ORPManagerDelegate
    func orpheDidUpdateBLEState(state:CBCentralManagerState){
        //PRINT("didUpdateBLEState", state)
        switch state {
        case .poweredOn:
            ORPManager.sharedInstance.startScan()
        default:
            break
        }
    }
    
    /*func orpheDidUpdateRSSI(orphe:ORPData){
       //print("didUpdateRSSI", orphe.RSSI)
        if let index = ORPManager.sharedInstance.availableORPDataArray.index(of: orphe){
            if let cell = tableView.view(atColumn: 1, row: index, makeIfNecessary: false) as? NSTableCellView{
                cell.textField?.stringValue = String(describing: orphe.RSSI)
            }
        }
    }*/
    
    func orpheDidDiscover(orphe:ORPData){
        print("\n Discovered device with UUID NUMBER \(orphe.uuid!)")
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidDisappear(orphe:ORPData){
        PRINT("didDisappearOrphe")
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidFailToConnect(orphe:ORPData){
        PRINT("didFailToConnect")
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidDisconnect(orphe:ORPData){
        PRINT("didDisconnect")
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidConnect(orphe:ORPData){
        print("\n DEVICE UUID NUMBER of is \(orphe.uuid!)")
        if (orphe.uuid!.uuidString == self.FIRST_PLAYER_LEFT_UUID){
            self.firstPlayerLeft.stringValue = "connected"
            self.firstPlayerLeft.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID) {
            self.firstPlayerRight.stringValue = "connected"
            self.firstPlayerRight.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) {
            self.secondPlayerLeft.stringValue = "connected"
            self.secondPlayerLeft.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID) {
            self.secondPlayerRight.stringValue = "connected"
            self.secondPlayerRight.textColor = NSColor.green
        }        
        tableView.reloadData()
        updateCellsState()
        self.shoesConnected = true
        OSCManager.sharedInstance.uuid = self.FIRST_PLAYER_LEFT_UUID
        
        self.gestureLabel.stringValue = self.gestures[Int(arc4random_uniform(UInt32(self.gestures.count)))]
        
        orphe.setScene(.sceneSDK)
        orphe.setGestureSensitivity(.high)
    }
    
    func orpheDidUpdateOrpheInfo(orphe:ORPData){
        PRINT("didUpdateOrpheInfo")
        for orp in ORPManager.sharedInstance.connectedORPDataArray {
            if orp != orphe && orp.side == orphe.side{
                orp.switchToOppositeSide()
                //PRINT("switch to opposite side")
            }
        }
    }
    
    //MARK: - Others
    /*@objc func readRSSI(){
        for orp in ORPManager.sharedInstance.connectedORPDataArray {
            orp.readRSSI()
        }
    }*/
    
    func orpheDidUpdateSensorData(orphe: ORPData) {
        let sideInfo:Int32 = Int32(orphe.side.rawValue)
        var text = ""
        let quat = orphe.getQuat()
        for (i, q) in quat.enumerated() {
            text += "Quat\(i): "+String(q) + "\n"
        }
        
        let euler = orphe.getEuler()
        for (i, e) in euler.enumerated() {
            text += "Euler\(i): "+String(e) + "\n"
        }
        
        let acc = orphe.getAcc()
        for (i, a) in acc.enumerated() {
            text += "Acc\(i): "+String(a) + "\n"
        }
        
        let gravity = orphe.getAccOfGravity()
        for (i, g) in gravity.enumerated() {
            text +=  "Gravity\(i): "+String(g) + "\n"
        }
        
        let gyro = orphe.getGyro()
        for (i, g) in gyro.enumerated() {
            text +=  "Gyro\(i): "+String(g) + "\n"
        }
        
        let mag = orphe.getMag()
        text +=  "Mag: "+String(mag) + "\n"
        
        let shock = orphe.getShock()
        text += "Shock: "+String(shock) + "\n"
        
        if sideInfo == 0 {
            leftSensorLabel.stringValue = "LEFT\n\n" + text + "\n" + leftGesture
        }
        else{
            rightSensorLabel.stringValue = "RIGHT\n\n" + text + "\n" + rightGesture
        }
    }
    
    func orpheDidCatchGestureEvent(gestureEvent:ORPGestureEventArgs, orphe:ORPData) {
        print("I catched a gesture.")
        let side = orphe.side
        let kind = gestureEvent.getGestureKindString() as String
        let power = gestureEvent.getPower()
        if side == ORPSide.left {
            leftGesture = "Gesture: " + kind + "\n"
            leftGesture += "power: " + String(power)
        }
        else{
            rightGesture = "Gesture: " + kind + "\n"
            rightGesture += "power: " + String(power)
        }
    }
}
extension ViewController: OSCManagerDelegate{
    func oscDidReceiveMessage(message:String) {        
        print(message)
    }
}
