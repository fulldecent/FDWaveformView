//
//  ViewController.swift
//  FDWaveformView
//
//  Created by William Entriken on 2/4/16.
//  Copyright © 2016 William Entriken. All rights reserved.
//

import Foundation
import UIKit
import FDWaveformView

class ViewController: UIViewController {
    @IBOutlet weak var waveform: FDWaveformView!
    @IBOutlet weak var logarithmicButton: UIButton!
    @IBOutlet weak var linearButton: UIButton!
    
    fileprivate var startRendering = Date()
    fileprivate var endRendering = Date()
    fileprivate var startLoading = Date()
    fileprivate var endLoading = Date()
    fileprivate var profileResult = ""
    
    @IBAction func doAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            let random = Int(arc4random()) % self.waveform.totalSamples
            self.waveform.highlightedSamples = 0 ..< random
        })
    }
    
    @IBAction func doZoomIn() {
        UIView.animate(withDuration: 0.3, animations: {
            self.waveform.zoomSamples = 0 ..< self.waveform.totalSamples / 4
            self.waveform.layoutIfNeeded() // hack https://stackoverflow.com/a/12285936/300224
        })
    }
    
    @IBAction func doZoomOut() {
        UIView.animate(withDuration: 0.3, animations: {
            self.waveform.zoomSamples = 0 ..< self.waveform.totalSamples
            self.waveform.layoutIfNeeded() // hack https://stackoverflow.com/a/12285936/300224
        })
    }
    
    ///TODO: figure out how to run these back-to-back
    @IBAction func doRunPerformanceProfile() {
        NSLog("RUNNING PERFORMANCE PROFILE")
        
        let alert = UIAlertController(title: "Start Profiling", message:"Profiling will begin, please don't touch anything. This will take less than 30 seconds.", preferredStyle: .alert)
        let action = UIAlertAction(title: "OK", style: .default)
        alert.addAction(action)
        present(alert, animated: true)
        
        self.profileResult = ""
        // Delay execution of my block for 1 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(1) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.profileResult.append("AAC:")
            self.doLoadAAC()
        })
        // Delay execution of my block for 5 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(5) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.profileResult.append(" MP3:")
            self.doLoadMP3()
        })
        /*
        // Delay execution of my block for 9 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(9) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.profileResult.append(" OGG:")
            self.doLoadOGG()
        })
        */
        // Delay execution of my block for 9 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(9) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            let alert = UIAlertController(title: "PLEASE POST TO github.com/fulldecent/FDWaveformView/wiki", message: self.profileResult, preferredStyle: .alert)
            let action = UIAlertAction(title: "OK", style: .default)
            alert.addAction(action)
            self.present(alert, animated: true)
        })
    }
    
    @IBAction func doLoadAAC() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "m4a")
        waveform.audioURL = url
    }
    
    @IBAction func doLoadMP3() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "mp3")
        waveform.audioURL = url
    }
    
    @IBAction func doLoadOGG() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "ogg")
        waveform.audioURL = url
    }
    
    @IBAction func toggleScrub(_ sender: UISwitch) {
        waveform.doesAllowScrubbing = sender.isOn
    }
    
    @IBAction func toggleStretch(_ sender: UISwitch) {
        waveform.doesAllowStretch = sender.isOn
    }
    
    @IBAction func toggleScroll(_ sender: UISwitch) {
        waveform.doesAllowScroll = sender.isOn
    }
    
    @IBAction func doLinear() {
        /* TODO: Make this public and then use it here
        waveform.waveformType = .linear
        updateWaveformTypeButtons()
         */
    }
    
    @IBAction func doLogarithmic() {
        /* TODO: Make this public and then use it here
        waveform.waveformType = .logarithmic
        updateWaveformTypeButtons()
        */
    }
    
    @IBAction func doChangeColors() {
        let randomColor: () -> (UIColor) = {
            return UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1)
        }
        
        UIView.animate(withDuration: 0.3, animations: {
            self.waveform.wavesColor = randomColor()
            self.waveform.progressColor = randomColor()
        })
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "Submarine", withExtension: "aiff")
        // Animate the waveform view when it is rendered
        waveform.delegate = self
        waveform.alpha = 0.0
        waveform.audioURL = url
        waveform.zoomSamples = 0 ..< waveform.totalSamples / 3
        waveform.doesAllowScrubbing = true
        waveform.doesAllowStretch = true
        waveform.doesAllowScroll = true
        updateWaveformTypeButtons()
    }
    
    func updateWaveformTypeButtons() {
        /* TODO: Make this public and then use it here
        let (selectedButton, nonSelectedButton): (UIButton, UIButton) = {
            switch waveform.waveformType {
            case .linear: return (linearButton, logarithmicButton)
            case .logarithmic: return (logarithmicButton, linearButton)
            }
        }()
        selectedButton.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        selectedButton.layer.borderWidth = 2
        nonSelectedButton.layer.borderWidth = 0
        */
    }
}

extension ViewController: FDWaveformViewDelegate {
    func waveformViewWillRender(_ waveformView: FDWaveformView) {
        startRendering = Date()
    }
    
    func waveformViewDidRender(_ waveformView: FDWaveformView) {
        endRendering = Date()
        NSLog("FDWaveformView rendering done, took %0.3f seconds", endRendering.timeIntervalSince(startRendering))
        profileResult.append(String(format: " render %0.3f ", endRendering.timeIntervalSince(startRendering)))
        UIView.animate(withDuration: 0.25, animations: {() -> Void in
            waveformView.alpha = 1.0
        })
    }
    
    func waveformViewWillLoad(_ waveformView: FDWaveformView) {
        startLoading = Date()
    }
    
    func waveformViewDidLoad(_ waveformView: FDWaveformView) {
        endLoading = Date()
        NSLog("FDWaveformView loading done, took %0.3f seconds", endLoading.timeIntervalSince(startLoading))
        profileResult.append(String(format: " load %0.3f ", endLoading.timeIntervalSince(startLoading)))
    }
}
