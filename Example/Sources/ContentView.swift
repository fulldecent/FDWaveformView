//
//  ContentView.swift
//  iOS Example
//
//  Created by William Entriken on Mar 27, 2024.
//

import FDWaveformView
import SwiftUI

// UIViewRepresentable wrapper for FDWaveformView
struct SwiftUIFDWaveformView: UIViewRepresentable {
    @Binding var audioURL: URL?
    var dataSource: FDWaveformDataSource?
    @Binding var canScrub: Bool
    @Binding var canStretch: Bool
    @Binding var canScroll: Bool
    @Binding var progress: Int?
    @Binding var wavesColor: Color?
    @Binding var backgroundColor: Color?
    @Binding var usesLogarithmicScale: Bool
    @Binding var zoomFactor: Double  // 1.0 = full, 2.0 = 2x zoom, etc.
    let delegate = FDWDelegate()

    func makeUIView(context: Context) -> FDWaveformView {
        let waveformView = FDWaveformView()
        waveformView.delegate = delegate
        return waveformView
    }

    func updateUIView(_ uiView: FDWaveformView, context: Context) {
        if let dataSource = dataSource {
            uiView.audioURL = nil
            uiView.dataSource = dataSource
        } else {
            uiView.dataSource = nil
            uiView.audioURL = audioURL
        }
        uiView.doesAllowScrubbing = canScrub
        uiView.doesAllowStretch = canStretch
        uiView.doesAllowScroll = canScroll
        uiView.usesLogarithmicScale = usesLogarithmicScale
        
        if let progress {
            uiView.highlightedSamples = 0..<progress
        }
        if let wavesColor {
            uiView.wavesColor = UIColor(wavesColor)
        }
        if let backgroundColor {
            uiView.backgroundColor = UIColor(backgroundColor)
        }
        
        // Apply zoom factor - zoom into the center
        let totalSamples = uiView.totalSamples
        if totalSamples > 0 && zoomFactor > 1.0 {
            let visibleSamples = Int(Double(totalSamples) / zoomFactor)
            let center = totalSamples / 2
            let start = max(0, center - visibleSamples / 2)
            let end = min(totalSamples, start + visibleSamples)
            uiView.zoomSamples = start..<end
        } else if totalSamples > 0 {
            uiView.zoomSamples = 0..<totalSamples
        }
    }
}

struct ContentView: View {
    @State private var audioURL: URL?
    @State private var dataSource: FDWaveformDataSource?
    @State private var isScrubActive = false
    @State private var isStretchActive = false
    @State private var isScrollActive = false
    @State private var progress: Int?
    @State private var wavesColor: Color?
    @State private var backgroundColor: Color?
    @State private var usesLogarithmicScale = true
    @State private var zoomFactor: Double = 1.0

    var body: some View {
        NavigationView {
            VStack {
                HStack {
                    Button("Load AAC") {
                        dataSource = nil
                        audioURL = nil
                        if let url = Bundle.main.url(
                            forResource: "TchaikovskyExample2", withExtension: "m4a")
                        {
                            audioURL = url
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("Load MP3") {
                        dataSource = nil
                        audioURL = nil
                        if let url = Bundle.main.url(
                            forResource: "TchaikovskyExample2", withExtension: "mp3")
                        {
                            audioURL = url
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Button("Sine Wave") {
                        audioURL = nil
                        // Generate a 5-second sine wave at 440Hz
                        dataSource = SineWaveSource(
                            frequency: 440.0,
                            duration: 5.0,
                            sampleRate: 44100.0,
                            modulationPeriod: 1.0
                        )
                    }
                    .buttonStyle(.borderedProminent)
                }

                HStack {
                    Button("Randomize Progress") {
                        // Random progress between 0 and 10000
                        progress = Int.random(in: 0...10000)
                    }
                    .buttonStyle(.bordered)

                    Button("Randomize Colors") {
                        // Generate random colors
                        wavesColor = Color(
                            red: Double.random(in: 0...1),
                            green: Double.random(in: 0...1),
                            blue: Double.random(in: 0...1)
                        )
                        backgroundColor = Color(
                            red: Double.random(in: 0...1),
                            green: Double.random(in: 0...1),
                            blue: Double.random(in: 0...1)
                        )
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("Zoom In") {
                        zoomFactor = min(zoomFactor * 2.0, 64.0)
                    }
                    .buttonStyle(.bordered)

                    Button("Zoom Out") {
                        zoomFactor = max(zoomFactor / 2.0, 1.0)
                    }
                    .buttonStyle(.bordered)
                }

                HStack {
                    Button("Logarithmic") {
                        usesLogarithmicScale = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(usesLogarithmicScale)

                    Button("Linear") {
                        usesLogarithmicScale = false
                    }
                    .buttonStyle(.bordered)
                    .disabled(!usesLogarithmicScale)
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
                    dataSource: dataSource,
                    canScrub: $isScrubActive,
                    canStretch: $isStretchActive,
                    canScroll: $isScrollActive,
                    progress: $progress,
                    wavesColor: $wavesColor,
                    backgroundColor: $backgroundColor,
                    usesLogarithmicScale: $usesLogarithmicScale,
                    zoomFactor: $zoomFactor
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
        NSLog(
            "FDWaveformView rendering done, took %0.3f seconds",
            endRendering.timeIntervalSince(startRendering))
        profileResult.append(
            String(format: " render %0.3f ", endRendering.timeIntervalSince(startRendering)))
        UIView.animate(
            withDuration: 0.25,
            animations: { () -> Void in
                waveformView.alpha = 1.0
            })
    }

    func waveformViewWillLoad(_ waveformView: FDWaveformView) {
        startLoading = Date()
    }

    func waveformViewDidLoad(_ waveformView: FDWaveformView) {
        endLoading = Date()
        NSLog(
            "FDWaveformView loading done, took %0.3f seconds",
            endLoading.timeIntervalSince(startLoading))
        profileResult.append(
            String(format: " load %0.3f ", endLoading.timeIntervalSince(startLoading)))
    }
}
