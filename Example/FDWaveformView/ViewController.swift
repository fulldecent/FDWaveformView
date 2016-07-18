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
    
    private var startRendering = NSDate()
    private var endRendering = NSDate()
    private var startLoading = NSDate()
    private var endLoading = NSDate()
    private var profilingAlert: UIAlertView? = nil
    private var profileResult = ""
    
    @IBAction func doAnimation() {
        UIView.animateWithDuration(0.3, animations: {
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
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(1) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
            self.profileResult.appendContentsOf("AAC:")
            self.doLoadAAC()
        })
        // Delay execution of my block for 5 seconds.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(5) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
            self.profileResult.appendContentsOf(" MP3:")
            self.doLoadMP3()
        })
        // Delay execution of my block for 9 seconds.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(9) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
            self.profileResult.appendContentsOf(" OGG:")
            self.doLoadOGG()
        })
        // Delay execution of my block for 14 seconds.
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, Int64(14) * Int64(NSEC_PER_SEC)), dispatch_get_main_queue(), {
            self.profilingAlert?.dismissWithClickedButtonIndex(-1, animated: false)
            let alert = UIAlertView(title: "PLEASE POST TO github.com/fulldecent/FDWaveformView/wiki", message: self.profileResult, delegate: nil, cancelButtonTitle: "Done", otherButtonTitles: "")
            alert.show()
            self.profilingAlert = alert
        })
    }
    
    @IBAction func doLoadAAC() {
        let thisBundle = NSBundle(forClass: self.dynamicType)
        let url = thisBundle.URLForResource("TchaikovskyExample2", withExtension: "m4a")
        self.waveform.audioURL = url
    }
    
    @IBAction func doLoadMP3() {
        let thisBundle = NSBundle(forClass: self.dynamicType)
        let url = thisBundle.URLForResource("TchaikovskyExample2", withExtension: "mp3")
        self.waveform.audioURL = url
    }
    
    @IBAction func doLoadOGG() {
        let thisBundle = NSBundle(forClass: self.dynamicType)
        let url = thisBundle.URLForResource("TchaikovskyExample2", withExtension: "ogg")
        self.waveform.audioURL = url
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        let thisBundle = NSBundle(forClass: self.dynamicType)
        let url = thisBundle.URLForResource("Submarine", withExtension: "aiff")
        // Animate the waveforme view in when it is rendered
        self.waveform.delegate = self
        self.waveform.alpha = 0.0
        self.waveform.audioURL = url
        self.waveform.progressSamples = 10000
        self.waveform.doesAllowScrubbing = true
        self.waveform.doesAllowStretch = true
        self.waveform.doesAllowScroll = true
    }
}

extension ViewController: FDWaveformViewDelegate {
    func waveformViewWillRender(waveformView: FDWaveformView) {
        self.startRendering = NSDate()
    }
    
    func waveformViewDidRender(waveformView: FDWaveformView) {
        self.endRendering = NSDate()
        NSLog("FDWaveformView rendering done, took %f seconds", self.endRendering.timeIntervalSinceDate(self.startRendering))
        self.profileResult.appendContentsOf(" render \(self.endRendering.timeIntervalSinceDate(self.startRendering))")
        UIView.animateWithDuration(0.25, animations: {() -> Void in
            waveformView.alpha = 1.0
        })
    }
    
    func waveformViewWillLoad(waveformView: FDWaveformView) {
        self.startLoading = NSDate()
    }
    
    func waveformViewDidLoad(waveformView: FDWaveformView) {
        self.endLoading = NSDate()
        NSLog("FDWaveformView loading done, took %f seconds", self.endLoading.timeIntervalSinceDate(self.startLoading))
        self.profileResult.appendContentsOf(" load \(self.endLoading.timeIntervalSinceDate(self.startLoading))")
    }
}
