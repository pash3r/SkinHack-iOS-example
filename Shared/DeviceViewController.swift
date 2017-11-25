//
//  DeviceViewController.swift
//  SwiftStarter
//
//  Created by Stephen Schiffli on 10/20/15.
//  Copyright © 2015 MbientLab Inc. All rights reserved.
//

import UIKit
import MetaWear
import MBProgressHUD

class DeviceViewController: UIViewController {
    
    @IBOutlet weak var deviceStatus: UILabel!
    @IBOutlet weak var ledOnOffButton: UIButton!
    @IBOutlet var lblSweat: [UILabel]!
    @IBOutlet weak var temperatureLabel: UILabel!
    @IBOutlet weak var accXLabel: UILabel!
    @IBOutlet weak var accYLabel: UILabel!
    @IBOutlet weak var accZLabel: UILabel!
    
    var events: [MBLEvent<MBLDataSample>] = [MBLEvent<MBLDataSample>]()
    
    var isLedOn: Bool = false
    var isAccelerometerMonitoring: Bool = false
    
    var device: MBLMetaWear!
    var bufferSweat: [[Double]] = []
    var timer: Timer?
    
    
    //MARK: - View lifecycle
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        MBProgressHUD.showAdded(to: view, animated: true)
        
        deviceStatus.text = "Connecting"
        
        device.connectAsync().success { _ in
            MBProgressHUD.hide(for: self.view, animated: true)
            
            self.deviceStatus.text = "Connected"
            print("We are connected")
            self.device.conductance?.gain = MBLConductanceGain.gain499K
            self.device.conductance?.voltage = MBLConductanceVoltage.voltage250mV
            self.device.conductance?.range = MBLConductanceRange.range100uS
            self.device.conductance?.calibrateAsync()
            self.device.led?.flashColorAsync(.green, withIntensity: 1.0, numberOfFlashes: 3)
        }.failure { error in
            MBProgressHUD.hide(for: self.view, animated: true)
            self.deviceStatus.text = error.localizedDescription
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        stopReadingSweatSensors()
        stopEventsObserving()
        device.led?.flashColorAsync(.green, withIntensity: 1.0, numberOfFlashes: 3)
        device.disconnectAsync()
    }
    
    //MARK: - Other
    func getOrientation() {
        guard let accelerometer = device.accelerometer as? MBLAccelerometerMMA8452Q else {
            return
        }
        
        let event = accelerometer.orientationEvent
        let casted = event as! MBLEvent<MBLDataSample>
        if !events.contains(casted) {
            events.append(casted)
        }
        
        event.startNotificationsAsync { (data, _) in
            guard let data = data else {
                return
            }
            
            print("orientation: \(data.orientation.rawValue)")
        }
    }
    
    
    @objc func readSensors(timer: Timer) {
        device.led?.setLEDOnAsync(false, withOptions: 0)
        device.led?.flashColorAsync(.green, withIntensity: 1.0, numberOfFlashes: 3)
        for i in 0...13 {
            device.conductance?.channels[i].readAsync().success({ (data) in
                print("result for sweat \(i)>> \(String(describing: data.value.doubleValue))")
                
                self.bufferSweat[i].append(data.value.doubleValue)
                
                let av = self.bufferSweat[i].average
                print ("AV: \(av)")
                
                DispatchQueue.main.async {
                    self.lblSweat[i].text = String(format: "%.0f", av)
                }
                
            })
        }
    }
    
    func stopEventsObserving() {
        guard events.count > 0 else {
            return
        }
        
        for e in events {
            e.stopNotificationsAsync()
        }
    }
    
}

//MARK: - IBActions
extension DeviceViewController {
    
    @IBAction func startReadingSweatSensors() {
        for _ in 0...13 {
            let buffer = [Double]()
            self.bufferSweat.append(buffer)
        }
        
        self.timer = nil
        self.timer = Timer.scheduledTimer(timeInterval: 5, target: self, selector: #selector(self.readSensors(timer:)), userInfo: self.device, repeats: true)
    }
    
    @IBAction func stopReadingSweatSensors() {
        timer?.invalidate()
        timer = nil
    }
    
    @IBAction func ledOnOffBtnTapped() {
        guard let led: MBLLED = device.led else {
            return
        }
        
        isLedOn = !isLedOn
        led.setLEDColorAsync(.green, withIntensity: CGFloat(isLedOn ? 1.0 : 0.0))
        getOrientation()
    }
    
    @IBAction func resetToFactory() {
        device.setConfigurationAsync(nil)
    }
    
    @IBAction func startStopAccelerometerMonitoring() {
        guard let a = device.accelerometer else {
            fatalError("\(#function) accelerometer is nil")
        }
        
        let event = a.dataReadyEvent
        if isAccelerometerMonitoring {
            event.stopNotificationsAsync()
        } else {
            event.startNotificationsAsync { [weak a] (data, error) in
                guard error == nil else {
                    a?.dataReadyEvent.stopNotificationsAsync()
                    fatalError("\(#function) error: \(error!)")
                }
                
                let data_ = data!
                DispatchQueue.main.async {
                    self.accXLabel.text = "X: \(data_.x)"
                    self.accYLabel.text = "Y: \(data_.y)"
                    self.accZLabel.text = "Z: \(data_.z)"
                }
            }
        }
        
        isAccelerometerMonitoring = !isAccelerometerMonitoring
    }
    
    @IBAction func getTemperature() {
        guard let temperature = device.temperature else {
            fatalError("\(#function) temperature is nil")
        }
        
        temperature.onboardThermistor?.readAsync().success({ data in
            DispatchQueue.main.async {
                self.temperatureLabel.text = data.value.stringValue.appending("°C")
            }
        })
    }
    
}
