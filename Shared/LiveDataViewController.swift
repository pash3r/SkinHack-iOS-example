//
//  LiveDataViewController.swift
//  BlueShirt
//
//  Created by BDF on 11.07.17.
//  Copyright © 2017 Stefan Hoppe. All rights reserved.
//

import Foundation
import MetaWear
import MBProgressHUD

class LiveDataViewController : UIViewController {
    
    var device : MBLMetaWear!

    var channelEvent: MBLTimerEvent<MBLDataSample>?
    
    var tempEvent: MBLEvent<MBLNumericData>?
    
    var batteryEvent: MBLEvent<MBLNumericData>?
    
    
    var rmsDataReadyEvent: MBLEvent<MBLRMSAccelerometerData>?
    
    var motionDataEvent : MBLEvent<MBLAccelerometerData>?
    
    var sweatEvents : [MBLEvent<MBLNumericData>]?
    
    @IBOutlet var lblSweat: [UILabel]!
    @IBOutlet weak var lblFirmware: UILabel!
    
    @IBOutlet weak var lblTemp: UILabel!
    @IBOutlet weak var lblMotion: UILabel!
    
    @IBOutlet weak var buttonStart: UIButton!
    @IBOutlet weak var buttonStop: UIButton!
    
    @IBOutlet weak var lblBattery: UILabel!
    
    var bufferSweat : [[Double]]?
    
    var is_streaming = false
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
//        if (ApplicationStates.shared.currentBoard == nil) {
//            showAlert("Error", message: "Device not set", completion: {
//                self.dismiss(animated: true, completion: nil)
//
//            })
        
//        } else {
            // if UserDefaults.standard.
            self.buffer_size = 1
            if (self.buffer_size! < 1) {
                self.buffer_size = 10
            }
//            self.device = ApplicationStates.shared.currentBoard!
            //  self.device.resetDevice()
            //self.device.setConfigurationAsync(nil)
//        }
        //self.device.read
    }
    
    let is_sweat_single = false
    var is_config_on_board = true;
    var buffer_size: Int?
    
    
    
    func startActiveSensors(board: MBLMetaWear) {
        
        rmsDataReadyEvent = board.accelerometer?.rmsDataReadyEvent.averageOfEvent(withDepth: 10).periodicSample(ofEvent: 100)
        rmsDataReadyEvent?.startNotificationsAsync(handler: { (result, error) in
            guard error == nil else {
                return
            }
            //   NSLog("\(result)")
            let s =  String( format: "%.1f", result!.rms * 1000.0)
            DispatchQueue.main.async {
                if (self.is_streaming) {
                    self.lblMotion.text = s
                } else {
                    self.lblMotion.text = "-"
                }
            }
        })
    }
    
    func stopStreamNotifications(board: MBLMetaWear) {
        rmsDataReadyEvent?.stopNotificationsAsync()
        //  board.accelerometer?.rmsDataReadyEvent.stopNotificationsAsync()
        board.temperature?.onboardThermistor?.removeNotificationHandlers()
        board.settings?.batteryRemaining?.removeNotificationHandlers()
        for i in 0...13 {
            board.conductance?.channels[i].removeNotificationHandlers()
        }
        
        lblMotion.text = "-"
        lblTemp.text = "-"
        lblBattery.text = "-"
        for i in 0...13 {
            lblSweat[i].text = "-"
        }
        buttonStart.isEnabled = true
        buttonStop.isEnabled = false
        
    }
    
    
    
    func startPassiveSensors(board: MBLMetaWear) {
        self.bufferSweat = [[Double]]()
        NSLog("READ SWEAT")
        
        for i in 0...13 {
            let buffer = [Double]()//FIFOQueue<Double>(arraysize: self.buffer_size!)
            self.bufferSweat?.append(buffer)
        }
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.readSensors(timer: )), userInfo: board, repeats: false)
    }
    
    
    
    @objc func readSensors(timer: Timer) {
        if (is_streaming == false) {
            return
        }
        
        let board = timer.userInfo as! MBLMetaWear
        board.temperature?.onboardThermistor?.readAsync().success({ (result) in
            DispatchQueue.main.async {
                if (self.is_streaming) {
                    self.lblTemp.text = String(format: "%.2f", result.value.doubleValue)
                } else {
                    self.lblTemp.text = "-"
                }
            }
        })
        board.readBatteryLifeAsync().success { (number) in
            DispatchQueue.main.async {
                if self.is_streaming {
                    self.lblBattery.text = String(format: "%.1f", number.doubleValue)
                } else {
                    self.lblBattery.text = "-"
                }
            }
        }
        for i in 0...13 {
            board.conductance?.channels[i].readAsync().success({ (data) in
                print("result for sweat \(i)>> \(String(describing: data.value.doubleValue))")
                
                self.bufferSweat?[i].append(data.value.doubleValue)
                
                let av = self.bufferSweat?[i].average
                print ("AV: \(av)")
                
                DispatchQueue.main.async {
                    //self.lblSweat[i].text = String(format: "%.0f", result!.value.doubleValue)
                    if (av != nil) {
                        if self.is_streaming {
                            self.lblSweat[i].text = String(format: "%.0f", av!)
                        } else {
                            self.lblSweat[i].text = "-"
                        }
                    }
                }
                
            })
        }
        
        Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.readSensors(timer: )), userInfo: board, repeats: false)
        
    }
    
    func setupWithoutConfig(board: MBLMetaWear) {
        print("setupWithoutConfig")
        if let accelerometer = self.device.accelerometer as? MBLAccelerometerMMA8452Q {
            accelerometer.fullScaleRange = .range8G  //.Range4G
            accelerometer.highPassFilter = true
            accelerometer.highPassCutoffFreq = MBLAccelerometerCutoffFreq.higheset
            accelerometer.sampleFrequency = 100
            

        }
        startActiveSensors(board: board)
        startPassiveSensors(board: board)
    }
    
    func setupWithExistingConfig(board: MBLMetaWear, config : DeviceConfiguration) {
        print("setupWithExistingConfig")
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.label.text = "Using Config"
        hud.mode = .indeterminate
        
//        ApplicationStates.shared.should_react_on_disconnect_signal = false
        
        DispatchQueue.main.async {
            hud.hide(animated: true)
        }
        
        self.device.temperature?.onboardThermistor?.addNotificationsHandler({ (result, error) in
            DispatchQueue.main.async {
                self.lblTemp.text = String(format: "%.2f", result!.value.doubleValue)
            }
        })
        self.device.settings?.batteryRemaining?.addNotificationsHandler({ (result, error) in
            DispatchQueue.main.async {
                
                self.lblBattery.text = String(format: "%.1f", result!.value.doubleValue)
            }
        })
        self.bufferSweat = [[Double]]()
        NSLog("READ SWEAT")
        for i in 0...13 {
            let buffer = [Double]()
            self.bufferSweat?.append(buffer)
            
            if let channel = self.device.conductance?.channels[i] {
                channel.addNotificationsHandler { (result, error) in
                    guard error == nil else {
                        NSLog("Unble to add notification: \(String(describing: error?.localizedDescription))")
                        return
                    }
                    print("result for sweat \(i)>> \(String(describing: result?.value.doubleValue))")
                    if (result?.value.doubleValue != nil) {
                        self.bufferSweat?[i].append((result?.value.doubleValue)!)
                    }
                    let av = self.bufferSweat?[i].average
                    print ("AV: \(av)")
                    
                    DispatchQueue.main.async {
                        //self.lblSweat[i].text = String(format: "%.0f", result!.value.doubleValue)
                        if (av != nil) {
                            self.lblSweat[i].text = String(format: "%.0f", av!)
                        }
                    }
                    
                }
            }
        }
        
        
//        config.rmsDataReadyEvent?.startNotificationsAsync(handler: { (result, error) in
//            guard error == nil else {
//                return
//            }
//            //   NSLog("\(result)")
//            let s =  String( format: "%.1f", result!.rms * 1000.0)
//            DispatchQueue.main.async {
//                self.lblMotion.text = s
//            }
//        })
        
        
    }
    
    func setupWithConfig() {
        let hud = MBProgressHUD.showAdded(to: self.view, animated: true)
        hud.label.text = "Please wait"
        hud.mode = .indeterminate
        
        //   let fifoQueue = FIFOQueue<Double>(arraysize: 5)
//        ApplicationStates.shared.should_react_on_disconnect_signal = false
//        self.device.setConfigurationAsync(<#T##configuration: MBLRestorable?##MBLRestorable?#>)
//            MyDeviceConfiguration(startLogging: false, interval: 1000, led_brightness: 1.0, offline_download_interval_s: 15)).success { (_) in
//            DispatchQueue.main.async {
//                hud.hide(animated: true)
//            }
            let config = self.device.configuration as! DeviceConfiguration
        
            self.device.temperature?.onboardThermistor?.addNotificationsHandler({ (result, error) in
                DispatchQueue.main.async {
                    self.lblTemp.text = String(format: "%.2f", result!.value.doubleValue)
                }
            })
            self.device.settings?.batteryRemaining?.addNotificationsHandler({ (result, error) in
                DispatchQueue.main.async {
                    
                    self.lblBattery.text = String(format: "%.1f", result!.value.doubleValue)
                }
            })
            self.bufferSweat = [[Double]]()
            NSLog("READ SWEAT")
            for i in 0...13 {
                let buffer = [Double]()
                self.bufferSweat?.append(buffer)
                
                if let channel = self.device.conductance?.channels[i] {
                    channel.addNotificationsHandler { (result, error) in
                        guard error == nil else {
                            NSLog("Unble to add notification: \(String(describing: error?.localizedDescription))")
                            return
                        }
                        print("result for sweat \(i)>> \(String(describing: result?.value.doubleValue))")
                        if (result?.value.doubleValue != nil) {
                            self.bufferSweat?[i].append((result?.value.doubleValue)!)
                        }
                        let av = self.bufferSweat?[i].average
                        print ("AV: \(av)")
                        
                        DispatchQueue.main.async {
                            //self.lblSweat[i].text = String(format: "%.0f", result!.value.doubleValue)
                            if (av != nil) {
                                self.lblSweat[i].text = String(format: "%.0f", av!)
                            }
                        }
                        
                    }
                }
        }
    }

        
            
//            config.rmsDataReadyEvent?.startNotificationsAsync(handler: { (result, error) in
//                guard error == nil else {
//                    return
//                }
//                //   NSLog("\(result)")
//                let s =  String( format: "%.1f", result!.rms * 1000.0)
//                DispatchQueue.main.async {
//                    self.lblMotion.text = s
//                }
//            })
        
            
//        }
//
//    }

    
    let should_use_config = false
    
    @IBAction func actionStartLive(_ sender: UIButton) {
        
        self.lblSweat.sort { (l0, l1) -> Bool in
            return l0.tag < l1.tag
        }
        is_streaming = true
        self.buttonStop.isEnabled = true
        self.buttonStart.isEnabled = false
        lblFirmware.text =  self.device.deviceInfo?.firmwareRevision
        
        let board = self.device
        
        if (should_use_config == false) {
            setupWithoutConfig(board: board!)
        } else {
            
            let config:String? = nil
            if (config != nil){
                is_config_on_board = true
//                setupWithExistingConfig(board: board!, config: config!)
                // setupWithConfig()
            } else {
                is_config_on_board = false
                
                let accelerometer = self.device.accelerometer as! MBLAccelerometerMMA8452Q
                
                //  accelerometer.fullScaleRange = .Range4G
                accelerometer.fullScaleRange = .range8G  //.Range4G
                accelerometer.highPassFilter = true
                accelerometer.highPassCutoffFreq = MBLAccelerometerCutoffFreq.higheset
                accelerometer.sampleFrequency = 100
                
                
                
                /*
                 motionDataEvent = accelerometer.dataReadyEvent
                 motionDataEvent?.startNotificationsAsync(handler: { (result, error) in
                 guard error == nil else {
                 return
                 }
                 //NSLog("Motion Data: \(result)")
                 })
                 */
                
                self.rmsDataReadyEvent =
                    accelerometer.rmsDataReadyEvent
                        .averageOfEvent(withDepth: 10).periodicSample(ofEvent: 100)
                
                self.rmsDataReadyEvent?.startNotificationsAsync(handler: { (result, error) in
                    guard error == nil else {
                        return
                    }
                    //   NSLog("\(result)")
                    let s =  String( format: "%.1f", result!.rms * 1000.0)
                    DispatchQueue.main.async {
                        self.lblMotion.text = s
                    }
                })
                
                self.tempEvent = self.device.temperature?.onboardThermistor?.periodicRead(withPeriod: 1000)
                self.batteryEvent = self.device.settings?.batteryRemaining?.periodicRead(withPeriod: 1000)
                
                
                self.tempEvent?.startNotificationsAsync(handler: { (result, error) in
                    guard error == nil else {
                        return
                    }
                    DispatchQueue.main.async {
                        
                        self.lblTemp.text = String(format: "%.2f", result!.value.doubleValue)
                    }
                    //  self.timerLabel.text = self.stringFromTimeInterval(NSDate().timeIntervalSinceDate(startDate))
                    
                })
                
                self.batteryEvent?.startNotificationsAsync(handler: { (result, error) in
                    guard error == nil else {
                        print("error reading battery")
                        return
                    }
                    DispatchQueue.main.async {
                        
                        self.lblBattery.text = String(format: "%.1f", result!.value.doubleValue)
                    }
                })
                
                
                self.device.conductance?.range = .range100uS
                self.device.conductance?.calibrateAsync()
                
                if (self.is_sweat_single) {
                    self.sweatEvents = [MBLEvent<MBLNumericData>]()
                    print("READ SWEAT")
                    for i in 0...13 {
                        if let channel = self.device.conductance?.channels[i] {
                            // Perform the read, since we are in a programCommandsToRunOnEvent block
                            // this read will perform each time channelEvent fires, which is every 500 ms
                            let v = channel.periodicRead(withPeriod: 1000)
                            self.sweatEvents?.append(v)
                            v.startNotificationsAsync(handler: { (data, error) in
                                guard error == nil else {
                                    return
                                }
                                DispatchQueue.main.async {
                                    
                                    self.lblSweat[i].text = String(format: "%.0f", (data?.value.doubleValue)!)
                                }
                                print("Ch\(i) \(String(describing: data?.value.doubleValue))")
                                
                            })
                            
                        }
                    }
                } else {
                    
                    /*
                     channelEvent = device.timer?.event(withPeriod: 500)
                     
                     channelEvent?.startNotificationsAsync(handler: { (data, error) in
                     
                     print("READ SWEAT")
                     for i in 0...13 {
                     if let channel = self.device.conductance?.channels[i] {
                     // Perform the read, since we are in a programCommandsToRunOnEvent block
                     // this read will perform each time channelEvent fires, which is every 500 ms
                     channel.readAsync()
                     
                     
                     // In order to actually get the data we need to attach a notification handler to the MBLData
                     channel.addNotificationsHandler { (result, error) in
                     guard error == nil else {
                     NSLog("Unble to add notification: \(String(describing: error?.localizedDescription))")
                     return
                     }
                     
                     DispatchQueue.main.async {
                     
                     
                     self.lblSweat[i].text = String(format: "%.0f", result!.value.doubleValue)
                     }
                     // NSLog("Index: %d >> %.0f", i, result!.value.doubleValue)
                     //   NSLog("Ch\(i) \(result.value.doubleValue)")
                     
                     }
                     }
                     }
                     })
                     
                     */
                    self.channelEvent = self.device.timer?.event(withPeriod: 500)
                    
                    
                    self.channelEvent?.programCommandsToRunOnEventAsync {
                        NSLog("READ SWEAT")
                        for i in 0...13 {
                            if let channel = self.device.conductance?.channels[i] {
                                // Perform the read, since we are in a programCommandsToRunOnEvent block
                                // this read will perform each time channelEvent fires, which is every 500 ms
                                channel.readAsync()
                                
                                /*.success({ (dev) in
                                 print ("added channel \(dev.value)")
                                 self.channels_set_success += 1
                                 })*/
                                
                                // In order to actually get the data we need to attach a notification handler to the MBLData
                                channel.addNotificationsHandler { (result, error) in
                                    guard error == nil else {
                                        NSLog("Unble to add notification: \(String(describing: error?.localizedDescription))")
                                        return
                                    }
                                    
                                    DispatchQueue.main.async {
                                        
                                        
                                        self.lblSweat[i].text = String(format: "%.0f", result!.value.doubleValue)
                                    }
                                    // NSLog("Index: %d >> %.0f", i, result!.value.doubleValue)
                                    //   NSLog("Ch\(i) \(result.value.doubleValue)")
                                    
                                }
                            }
                        }
                    }
                }
                
            }
            
            
        }
    }
    var channels_set_success : Int = 0
    
    @IBAction func actionStopLive(_ sender: UIButton) {
        //let accelerometer = device.accelerometer as! MBLAccelerometerMMA8452Q
        //rmsDataReadyEvent?.stopNotificationsAsync()
        //tempEvent?.stopNotificationsAsync()
        is_streaming = false
        if (self.should_use_config == false) {
            print("Stopping all notifications")
            let board = self.device
            stopStreamNotifications(board: board!)
            print("notifications stopped")
            return
        }
        
        print("Checking Notification States")
        print("Temperature: \(String(describing: tempEvent?.isNotifying()))")
        print("Motion General: \(String(describing: motionDataEvent?.isNotifying()))")
        print("Motion RMS: \(String(describing: rmsDataReadyEvent?.isNotifying()))")
        print("Conduction: \(String(describing: channelEvent?.isNotifying()))")
        
        print("Stopping all notifications")
        
        if (is_config_on_board) {
            device.temperature?.onboardThermistor?.removeNotificationHandlers()
//            let config = self.device.configuration as! MyDeviceConfiguration
//            // Stop the main event timer from firing commands
//            config.mainTimerEvent?.eraseCommandsToRunOnEventAsync()
//            for i in 0...13 {
//                if let channel = self.device.conductance?.channels[i] {
//                    channel.removeNotificationHandlers()
//                }
//            }
            
//            config.rmsDataReadyEvent?.stopNotificationsAsync()
            buttonStart.isEnabled = true
            buttonStop.isEnabled = false
            
            
        } else {
            
            if (motionDataEvent != nil && motionDataEvent!.isNotifying()) {
                motionDataEvent?.stopNotificationsAsync().success({ (_) in
                    print("motion event stopped")
                }).failure({ (error) in
                    print("motion event not stopped")
                })
            }
            
            if (tempEvent != nil && tempEvent!.isNotifying()) {
                
                tempEvent?.stopNotificationsAsync().success({ (_) in
                    print("Temperature Stopped")
                })
            }
            
            if (batteryEvent != nil && batteryEvent!.isNotifying()) {
                
                batteryEvent?.stopNotificationsAsync().success({ (_) in
                    print("Battery Stopped")
                })
            }
            
            
            if rmsDataReadyEvent != nil && rmsDataReadyEvent!.isNotifying() {
                
                rmsDataReadyEvent?.stopNotificationsAsync().success({ (_) in
                    print("rmsDataReadyEvent event stopped")
                }).failure({ (error) in
                    print("rmsDataReadyEvent event not stopped")
                })
                
            }
            print ("channels that where initialized corrrectly: \(self.channels_set_success)")
            
            if (is_sweat_single) {
                for v in sweatEvents! {
                    v.stopNotificationsAsync()
                    
                }
            } else {
                
                channelEvent?.stopNotificationsAsync().success({ (_) in
                    print("Conductance notification stopped")
                }).failure({ (error) in
                    print("Conductance notification not stopped")
                })
                
                print("Erase commands")
                channelEvent?.eraseCommandsToRunOnEventAsync().success({ (_) in
                    
                    for i in 0...13 {
                        if ( i < (self.device.conductance?.channels.count)!) {
                            if let channel = self.device.conductance?.channels[i] {
                                NSLog("remove Channel \(i)")
                                channel.removeNotificationHandlers()
                            }
                        }
                    }
                    
                    
                    
                }).failure({ (error) in
//                    self.showAlert("Warning", message: "Unable to erase commands")
                }).success({ (_) in
                    NSLog("Commands erased: \(String(describing: self.channelEvent?.hasCommands()))")
                })
                
                
            }
            
            
            print("Recheck notifications stopped")
             print("Temperature: \(String(describing: tempEvent?.isNotifying()))")
             print("Motion General: \(String(describing: motionDataEvent?.isNotifying()))")
             print("Motion RMS: \(String(describing: rmsDataReadyEvent?.isNotifying()))")
              print("Conduction: \(String(describing: channelEvent?.isNotifying()))")
            buttonStart.isEnabled = true
            buttonStop.isEnabled = false
        }
        
        
        
    }
    
    }
