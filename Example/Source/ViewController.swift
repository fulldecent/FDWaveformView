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
    @IBOutlet var playButton: UIView!
    @IBOutlet weak var logarithmicButton: UIButton!
    @IBOutlet weak var linearButton: UIButton!
    
    fileprivate var startRendering = Date()
    fileprivate var endRendering = Date()
    fileprivate var startLoading = Date()
    fileprivate var endLoading = Date()
    fileprivate var profilingAlert: UIAlertView? = nil
    fileprivate var profileResult = ""
    
    @IBAction func doAnimation() {
        UIView.animate(withDuration: 0.3, animations: {
            let randomNumber = Int(arc4random()) % self.waveform.totalSamples
            self.waveform.progressSamples = randomNumber
        })
    }
    
    @IBAction func doZoomIn() {
        self.waveform.zoomStartSamples = 0
        self.waveform.zoomEndSamples = self.waveform.totalSamples / 4
    }
    
    @IBAction func doZoomOut() {
        self.waveform.zoomStartSamples = 0
        self.waveform.zoomEndSamples = self.waveform.totalSamples
    }
    
    @IBAction func doRunPerformanceProfile() {
        NSLog("RUNNING PERFORMANCE PROFILE")
        let alert = UIAlertView(title: "PROFILING BEGIN", message: "Profiling will begin, please don't touch anything. This will take less than 30 seconds", delegate: nil, cancelButtonTitle: nil, otherButtonTitles: "")
        alert.show()
        self.profilingAlert = alert
        
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
        // Delay execution of my block for 9 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(9) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.profileResult.append(" OGG:")
            self.doLoadOGG()
        })
        // Delay execution of my block for 14 seconds.
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(Int64(14) * Int64(NSEC_PER_SEC)) / Double(NSEC_PER_SEC), execute: {
            self.profilingAlert?.dismiss(withClickedButtonIndex: -1, animated: false)
            let alert = UIAlertView(title: "PLEASE POST TO github.com/fulldecent/FDWaveformView/wiki", message: self.profileResult, delegate: nil, cancelButtonTitle: "Done", otherButtonTitles: "")
            alert.show()
            self.profilingAlert = alert
        })
    }
    
    @IBAction func doLoadAAC() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "m4a")
        self.waveform.audioURL = url
    }
    
    @IBAction func doLoadMP3() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "mp3")
        self.waveform.audioURL = url
    }
    
    @IBAction func doLoadOGG() {
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "TchaikovskyExample2", withExtension: "ogg")
        self.waveform.audioURL = url
    }
    
    @IBAction func doLinear() {
        self.waveform.waveformType = .linear
        updateWaveformTypeButtons()
    }
    
    @IBAction func doLogarithmic() {
        self.waveform.waveformType = .logarithmic
        updateWaveformTypeButtons()
    }
    
    @IBAction func doChangeColors() {
        let randomColor: () -> (UIColor) = {
            return UIColor(red: CGFloat(drand48()), green: CGFloat(drand48()), blue: CGFloat(drand48()), alpha: 1)
        }
        
        self.waveform.wavesColor = randomColor()
        self.waveform.progressColor = randomColor()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let thisBundle = Bundle(for: type(of: self))
        let url = thisBundle.url(forResource: "Submarine", withExtension: "aiff")
        // Animate the waveforme view in when it is rendered
        self.waveform.delegate = self
        self.waveform.alpha = 0.0
        self.waveform.audioURL = url
        self.waveform.progressSamples = 10000
        self.waveform.doesAllowScrubbing = true
        self.waveform.doesAllowStretch = true
        self.waveform.doesAllowScroll = true
        updateWaveformTypeButtons()
    }
    
    func updateWaveformTypeButtons() {
        let (selectedButton, nonSelectedButton): (UIButton, UIButton) = {
            switch self.waveform.waveformType {
            case .linear: return (self.linearButton, self.logarithmicButton)
            case .logarithmic: return (self.logarithmicButton, self.linearButton)
            }
        }()
        selectedButton.layer.borderColor = #colorLiteral(red: 0, green: 0, blue: 0, alpha: 0.25).cgColor
        selectedButton.layer.borderWidth = 2
        nonSelectedButton.layer.borderWidth = 0
    }
}

extension ViewController: FDWaveformViewDelegate {
    func waveformViewWillRender(_ waveformView: FDWaveformView) {
        self.startRendering = Date()
    }
    
    func waveformViewDidRender(_ waveformView: FDWaveformView) {
        self.endRendering = Date()
        NSLog("FDWaveformView rendering done, took %f seconds", self.endRendering.timeIntervalSince(self.startRendering))
        self.profileResult.append(" render \(self.endRendering.timeIntervalSince(self.startRendering))")
        UIView.animate(withDuration: 0.25, animations: {() -> Void in
            waveformView.alpha = 1.0
        })
    }
    
    func waveformViewWillLoad(_ waveformView: FDWaveformView) {
        self.startLoading = Date()
    }
    
    func waveformViewDidLoad(_ waveformView: FDWaveformView) {
        self.endLoading = Date()
        NSLog("FDWaveformView loading done, took %f seconds", self.endLoading.timeIntervalSince(self.startLoading))
        self.profileResult.append(" load \(self.endLoading.timeIntervalSince(self.startLoading))")
    }
}
