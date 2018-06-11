//
//  ViewController.swift
//  Shared-Action
//
//  Created by Marla Na on 09.06.18.
//  Copyright © 2018 Marla Na. All rights reserved.
//

import Cocoa
import Orphe
import OSCKit

class ViewController: NSViewController {
    
    //MARK: UUID Orphe Data
    // First player: White shoes, Second player: Black shoes
    let FIRST_PLAYER_LEFT_UUID = "DF88A432-0317-4524-8479-CB84AAB5C9A1"
    let FIRST_PLAYER_RIGHT_UUID = "A0A2DB4C-F967-41AF-B4C4-44229AE535F3"
    let SECOND_PLAYER_LEFT_UUID = "2FF443A0-FFF9-4317-8C7F-30321B14B779"
    let SECOND_PLAYER_RIGHT_UUID = "7E186EAA-6E8E-40F2-B91D-C0E92D830254"
    
    //MARK: IBOutlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var firstPlayer_leftSensorData: NSTextField!
    @IBOutlet weak var firstPlayer_rightSensorData: NSTextField!
    @IBOutlet weak var secondPlayer_leftSensorData: NSTextField!
    @IBOutlet weak var secondPlayer_rightSensorData: NSTextField!
    @IBOutlet weak var firstPlayerLeftConnected: NSTextField!
    @IBOutlet weak var firstPlayerRightConnected: NSTextField!
    @IBOutlet weak var secondPlayerLeftConnected: NSTextField!
    @IBOutlet weak var secondPlayerRightConnected: NSTextField!
    @IBOutlet weak var gestureDetectedLabel: NSTextField!
    var rssiTimer: Timer?
    
    var leftGesture = ""
    var rightGesture = ""
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.target = self
        tableView.allowsTypeSelect = false
        
        ORPManager.sharedInstance.delegate = self
        ORPManager.sharedInstance.isEnableAutoReconnection = false
        ORPManager.sharedInstance.startScan()
        
        //TODO: Uncomment when not debugging
        //rssiTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(ViewController.readRSSI), userInfo: nil, repeats: true)
        
        //OSC view
        OSCManager.sharedInstance.delegate = self
    }
    
    func updateCellsState() {
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

//MARK: TableViewDelegate
extension  ViewController: NSTableViewDelegate {
    
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

//MARK: TableViewDataSource
extension ViewController: NSTableViewDataSource {
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return ORPManager.sharedInstance.availableORPDataArray.count
    }
}

//MARK: ORPManagerDelegate
extension  ViewController: ORPManagerDelegate {
    
    func orpheDidUpdateBLEState(state:CBCentralManagerState) {
        switch state {
        case .poweredOn:
            ORPManager.sharedInstance.startScan()
        default:
            break
        }
    }
    
    //TODO: Uncomment when not debugging
    /*func orpheDidUpdateRSSI(orphe:ORPData) {
     //print("didUpdateRSSI", orphe.RSSI)
     if let index = ORPManager.sharedInstance.availableORPDataArray.index(of: orphe){
     if let cell = tableView.view(atColumn: 1, row: index, makeIfNecessary: false) as? NSTableCellView{
     cell.textField?.stringValue = String(describing: orphe.RSSI)
     }
     }
     }*/
    
    func orpheDidDiscover(orphe:ORPData) {
        print("\n Discovered device with UUID NUMBER \(orphe.uuid!)")
        self.updateOnProblem(orphe: orphe)
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidDisappear(orphe:ORPData) {
        print("\n DEVICE \(orphe.uuid!) disappeared.")
        self.updateOnProblem(orphe: orphe)
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidFailToConnect(orphe:ORPData) {
        print("\n Failed to connect to DEVICE \(orphe.uuid!).")
        self.updateOnProblem(orphe: orphe)
        tableView.reloadData()
        updateCellsState()
    }
    
    func orpheDidDisconnect(orphe:ORPData) {
        print("\n Disconnected from DEVICE \(orphe.uuid!).")
        self.updateOnProblem(orphe: orphe)
        tableView.reloadData()
        updateCellsState()
    }
    
    func updateOnProblem(orphe:ORPData) {
        if (orphe.uuid!.uuidString == self.FIRST_PLAYER_LEFT_UUID){
            self.firstPlayerLeftConnected.stringValue = "disconnected"
            self.firstPlayerLeftConnected.textColor = NSColor.red
        } else if (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID) {
            self.firstPlayerRightConnected.stringValue = "disconnected"
            self.firstPlayerRightConnected.textColor = NSColor.red
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) {
            self.secondPlayerLeftConnected.stringValue = "disconnected"
            self.secondPlayerLeftConnected.textColor = NSColor.red
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID) {
            self.secondPlayerRightConnected.stringValue = "disconnected"
            self.secondPlayerRightConnected.textColor = NSColor.red
        }
    }
    
    func orpheDidConnect(orphe:ORPData) {
        print("\n Connected with DEVICE \(orphe.uuid!).")
        if (orphe.uuid!.uuidString == self.FIRST_PLAYER_LEFT_UUID){
            self.firstPlayerLeftConnected.stringValue = "connected"
            self.firstPlayerLeftConnected.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID) {
            self.firstPlayerRightConnected.stringValue = "connected"
            self.firstPlayerRightConnected.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) {
            self.secondPlayerLeftConnected.stringValue = "connected"
            self.secondPlayerLeftConnected.textColor = NSColor.green
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID) {
            self.secondPlayerRightConnected.stringValue = "connected"
            self.secondPlayerRightConnected.textColor = NSColor.green
        }        
        tableView.reloadData()
        updateCellsState()
        
        orphe.setScene(.sceneSDK)
        orphe.setGestureSensitivity(.high)
    }
    
    func orpheDidUpdateOrpheInfo(orphe:ORPData) {
        PRINT("didUpdateOrpheInfo")
        for orp in ORPManager.sharedInstance.connectedORPDataArray {
            if orp != orphe && orp.side == orphe.side{
                orp.switchToOppositeSide()
            }
        }
    }
    
    //MARK: Uncomment when not debugging
    /*@objc func readRSSI() {
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
        
        // Current game logic: Each of the two players only use one foot. FP uses the left foot and SP uses the right foot.
        if sideInfo == 0 {
            firstPlayer_leftSensorData.stringValue = "FIRST PLAYER \n LEFT\n\n" + text + "\n" + leftGesture
        }
        else {
            secondPlayer_rightSensorData.stringValue = "SECOND PLAYER \n RIGHT\n\n" + text + "\n" + rightGesture
        }
    }
    
    func orpheDidCatchGestureEvent(gestureEvent:ORPGestureEventArgs, orphe:ORPData) {
        let uuid = orphe.uuid!
        let side = orphe.side
        let kind = gestureEvent.getGestureKindString() as String
        let power = gestureEvent.getPower()
        if (uuid.uuidString == self.FIRST_PLAYER_LEFT_UUID) {
            print("FIRST PLAYER LEFT FOOT MADE \(kind) gesture with power \(power).")
            
        } else if (orphe.uuid!.uuidString == self.FIRST_PLAYER_RIGHT_UUID) {
            print("FIRST PLAYER RIGHT FOOT MADE \(kind) gesture with power \(power).")
            
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_LEFT_UUID) {
            print("SECOND PLAYER LEFT FOOT MADE \(kind) gesture with power \(power).")
            
        } else if (orphe.uuid!.uuidString == self.SECOND_PLAYER_RIGHT_UUID) {
            print("SECOND PLAYER RIGHT FOOT MADE \(kind) gesture with power \(power).")
            
        }
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
//MARK: OSCManagerDelegate
extension ViewController: OSCManagerDelegate {
    func oscDidReceiveMessage(message:String) {        
        print(message)
    }
}
