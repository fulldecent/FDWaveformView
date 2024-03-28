//
//  ContentView.swift
//  iOS Example
//
//  Created by William Entriken on Mar 27, 2024.
//

import SwiftUI
import FDWaveformView

// UIViewRepresentable wrapper for FDWaveformView
struct SwiftUIFDWaveformView: UIViewRepresentable {
    @Binding var audioURL: URL?
    @Binding var canScrub: Bool
    @Binding var canStretch: Bool
    @Binding var canScroll: Bool
    @Binding var progress: Int?
    @Binding var wavesColor: Color?
    @Binding var backgroundColor: Color?
    let delegate = FDWDelegate()

    func makeUIView(context: Context) -> FDWaveformView {
        let waveformView = FDWaveformView()
        // TODO, this delegate is not actually connected
        waveformView.delegate = delegate
        return waveformView
    }

    func updateUIView(_ uiView: FDWaveformView, context: Context) {
        uiView.audioURL = audioURL
        uiView.doesAllowScrubbing = canScrub
        uiView.doesAllowStretch = canStretch
        uiView.doesAllowScroll = canScroll
        if let progress {
            uiView.highlightedSamples = 0..<progress
        }
        if let wavesColor {
            uiView.wavesColor = UIColor(wavesColor)
        }
        if let backgroundColor {
            uiView.backgroundColor = UIColor(backgroundColor)
        }
        // Add other property updates if needed
    }
}

struct ContentView: View {
    @State private var audioURL: URL?
    @State private var isScrubActive = false
    @State private var isStretchActive = false
    @State private var isScrollActive = false
    @State private var progress: Int?
    @State private var wavesColor: Color?
    @State private var backgroundColor: Color?

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("Load AAC") {
                        audioURL = nil
                        if let url = Bundle.main.url(forResource: "TchaikovskyExample2", withExtension: "m4a") {
                            audioURL = url
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Load MP3") {
                        audioURL = nil
                        if let url = Bundle.main.url(forResource: "TchaikovskyExample2", withExtension: "mp3") {
                            audioURL = url
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                HStack {
                    Button("Randomize Progress") {
                        // TODO: fix this
                        // how to load the samples count?
                        progress = 4000
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Randomize Colors") {
                        // XKCD #221
                        wavesColor = .red
                        backgroundColor = .blue
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Button("Zoom In") {
                        // TODO: fix this
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Zoom Out") {
                        // TODO: fix this
                    }
                    .buttonStyle(.bordered)
                }
                
                HStack {
                    Button("Logarithmic") {
                        // TODO: fix this
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Linear") {
                        // TODO: fiw this
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("Run Performance Profiling") {
                    /*
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
                     
                     */
                }
                .buttonStyle(.borderedProminent)
                
                HStack {
                    Toggle("Scrub", isOn: $isScrubActive)
                    Toggle("Stretch", isOn: $isStretchActive)
                    Toggle("Scroll", isOn: $isScrollActive)
                }
                .padding()
                
                SwiftUIFDWaveformView(
                    audioURL: $audioURL,
                    canScrub: $isScrubActive,
                    canStretch: $isStretchActive,
                    canScroll: $isScrollActive,
                    progress: $progress,
                    wavesColor: $wavesColor,
                    backgroundColor: $backgroundColor
                )
                    .onAppear {
                        if let url = Bundle.main.url(forResource: "Submarine", withExtension: "aiff") {
                            audioURL = url
                        }
                    }
                    .frame(height: 200)
            }
            .padding()
        }
    }
}

#Preview {
    ContentView()
}

class FDWDelegate: NSObject, FDWaveformViewDelegate {
    fileprivate var startRendering = Date()
    fileprivate var endRendering = Date()
    fileprivate var startLoading = Date()
    fileprivate var endLoading = Date()
    fileprivate var profileResult = ""

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
