//
//  ViewController.swift
//  Shared-Action
//
//  Created by Marla Na on 09.06.18.
//  Copyright © 2018 Marla Na. All rights reserved.
//

import Cocoa
import Orphe

class ViewController: NSViewController {
    
    //MARK: UUID Orphe Data
    var PLAYER_LEFT_UUID = "DF88A432-0317-4524-8479-CB84AAB5C9A1"
    var PLAYER_RIGHT_UUID = "A0A2DB4C-F967-41AF-B4C4-44229AE535F3"
    var UUID_CURRENT = [("27A","DF88A432-0317-4524-8479-CB84AAB5C9A1","A0A2DB4C-F967-41AF-B4C4-44229AE535F3"),("27B", "2FF443A0-FFF9-4317-8C7F-30321B14B779","7E186EAA-6E8E-40F2-B91D-C0E92D830254"),("29A","D9F50138-ED69-42A6-A8B1-F207412EEEA5","E8BB1A87-CB22-4C0F-8E08-3E1F120BA512"), ("29B","94ACE614-7094-4F1E-AC0A-88348982DDE2","52BB0869-0265-4C6A-9741-9A96CE2B27B0")]
    var UUID_KATIE = [("27A","63329941-E15E-43CF-8751-AB3662F2AA2B","04691D5E-D052-42D7-B77E-FF6FC4F9C613"),("27B","E23DE230-C2C2-4024-A65F-A32CE49DB52D","E65331B0-60E6-412F-85A6-FABDFCDF3AB8"),("29A","BFE30CB4-3225-4D69-8560-952A4A99B019","F869D546-9A9E-4318-8FDD-DF6F723965B8"),("29B","xxx","xxxx")]
    var UUID_MARLA = [("27A","DF88A432-0317-4524-8479-CB84AAB5C9A1","A0A2DB4C-F967-41AF-B4C4-44229AE535F3"),("27B", "2FF443A0-FFF9-4317-8C7F-30321B14B779","7E186EAA-6E8E-40F2-B91D-C0E92D830254"),("29A","D9F50138-ED69-42A6-A8B1-F207412EEEA5","E8BB1A87-CB22-4C0F-8E08-3E1F120BA512"), ("29B","94ACE614-7094-4F1E-AC0A-88348982DDE2","52BB0869-0265-4C6A-9741-9A96CE2B27B0")]
    var selected_shoes = "27A"
    
    //MARK: IBOutlets
    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var firstPlayer_leftSensorData: NSTextField!
    @IBOutlet weak var firstPlayer_rightSensorData: NSTextField!
    @IBOutlet weak var firstPlayerLeftConnected: NSTextField!
    @IBOutlet weak var firstPlayerRightConnected: NSTextField!
    @IBOutlet weak var currentLaptop_Label: NSTextField!
    @IBOutlet weak var ip_TextField: NSTextField!
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
    
    func setUUID(){
        for pair in self.UUID_CURRENT {
            if (self.selected_shoes == pair.0){
                self.PLAYER_LEFT_UUID = pair.1
                self.PLAYER_RIGHT_UUID = pair.2
            }
        }
    }
    
    @IBAction func changeUUID(_ sender: NSButton) {
        if( self.currentLaptop_Label.stringValue == "Marla"){
            sender.title = "Change to Marla"
            self.currentLaptop_Label.stringValue = "Katie"
            self.UUID_CURRENT = self.UUID_KATIE
            self.setUUID()
        } else if (self.currentLaptop_Label.stringValue == "Katie"){
            sender.title = "Change to Katie"
            self.currentLaptop_Label.stringValue = "Marla"
            self.UUID_CURRENT = self.UUID_MARLA
            self.setUUID()
        }
    }
    
    @IBAction func changeIP(_ sender: NSButton) {
        OSCManager.sharedInstance.clientPath = "http://" + self.ip_TextField.stringValue
    }
    
    @IBAction func changeShoes(_ sender: NSPopUpButton) {
        self.selected_shoes = sender.selectedItem!.title
        self.setUUID()
    }
    
    override func keyDown(with theEvent: NSEvent) {
        super.keyDown(with: theEvent)
        if let lightNum:UInt8 = UInt8(theEvent.characters!){
            for orp in ORPManager.sharedInstance.connectedORPDataArray{
                orp.triggerLight(lightNum: lightNum)
                orp.triggerLight(lightNum: lightNum)
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
        if (tableView.selectedRow != -1) {
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
        if (orphe.uuid!.uuidString == self.PLAYER_LEFT_UUID){
            self.firstPlayerLeftConnected.stringValue = "disconnected"
            self.firstPlayerLeftConnected.textColor = NSColor.red
        } else if (orphe.uuid!.uuidString == self.PLAYER_RIGHT_UUID) {
            self.firstPlayerRightConnected.stringValue = "disconnected"
            self.firstPlayerRightConnected.textColor = NSColor.red
        }
    }
    
    func orpheDidConnect(orphe:ORPData) {
        //MARK: Orphe framework bug changing sides of shoes
        print("\n Connected with DEVICE \(orphe.uuid!).")
        if (orphe.uuid!.uuidString == self.PLAYER_LEFT_UUID){
            self.firstPlayerLeftConnected.stringValue = "connected"
            self.firstPlayerLeftConnected.textColor = NSColor.green
            if (orphe.side == .right){
                orphe.switchToOppositeSide()
            }
        } else if (orphe.uuid!.uuidString == self.PLAYER_RIGHT_UUID) {
            self.firstPlayerRightConnected.stringValue = "connected"
            self.firstPlayerRightConnected.textColor = NSColor.green
            if (orphe.side == .left){
                orphe.switchToOppositeSide()
            }
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
               // orp.switchToOppositeSide()
            }
        }
    }
    
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
        if (orphe.uuid!.uuidString == self.PLAYER_LEFT_UUID && sideInfo == 0){
            firstPlayer_leftSensorData.stringValue = "EXPERT \n LEFT\n\n" + text + "\n"
        } else if (orphe.uuid!.uuidString == self.PLAYER_RIGHT_UUID) {
            firstPlayer_rightSensorData.stringValue = "EXPERT \n RIGHT\n\n" + text + "\n"
        }
    }
    
    /*
     This method describes the feedback shown to the user when he performs the gestures. Regardless of the game, the shoes always show feedback.
     */
    func orpheDidCatchGestureEvent(gestureEvent:ORPGestureEventArgs, orphe:ORPData) {
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
        switch gestureEvent.getGestureKind() {
        case .STEP_TOE:
            orphe.triggerLight(lightNum: 9)
        case .STEP_HEEL:
            orphe.triggerLight(lightNum: 9)            
        default:
            break
        }
    }
}
//MARK: OSCManagerDelegate
extension ViewController: OSCManagerDelegate {
    func oscDidReceiveMessage(message:String) {        
        print(message)
    }
}
