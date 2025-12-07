//
// Copyright (c) William Entriken and the FDWaveformView contributors
//

import FDWaveformView
import SwiftUI

// UIViewRepresentable wrapper for FDWaveformView
struct SwiftUIFDWaveformView: UIViewRepresentable {
  @Binding var audioURL: URL?
  @Binding var canScrub: Bool
  @Binding var canStretch: Bool
  @Binding var canScroll: Bool
  @Binding var progress: Int?
  @Binding var wavesColor: Color?
  @Binding var backgroundColor: Color?
  @Binding var zoomToMiddle50Percent: Bool
  @Binding var isLogarithmic: Bool
  var zoomChangeCounter: Int
  var onTotalSamplesChanged: ((Int) -> Void)?
  var onRenderComplete: (() -> Void)?

  func makeCoordinator() -> Coordinator {
    Coordinator(onTotalSamplesChanged: onTotalSamplesChanged, onRenderComplete: onRenderComplete)
  }

  func makeUIView(context: Context) -> FDWaveformView {
    let waveformView = FDWaveformView()
    waveformView.delegate = context.coordinator
    return waveformView
  }

  func updateUIView(_ uiView: FDWaveformView, context: Context) {
    // Only update audioURL if it actually changed to avoid re-triggering load
    if uiView.audioURL != audioURL {
      uiView.audioURL = audioURL
    }
    uiView.doesAllowScrubbing = canScrub
    uiView.doesAllowStretch = canStretch
    uiView.doesAllowScroll = canScroll
    if let progress {
      uiView.highlightedSamples = 0..<progress
    } else {
      uiView.highlightedSamples = nil
    }
    if let wavesColor {
      uiView.wavesColor = UIColor(wavesColor)
    }
    if let backgroundColor {
      uiView.backgroundColor = UIColor(backgroundColor)
    }

    // Handle zoom - only apply when button is pressed (counter changed)
    // Don't reset zoom when other properties change
    let totalSamples = uiView.totalSamples
    if totalSamples > 0 && zoomChangeCounter != context.coordinator.lastZoomChangeCounter {
      context.coordinator.lastZoomChangeCounter = zoomChangeCounter
      if zoomToMiddle50Percent {
        let quarter = totalSamples / 4
        uiView.zoomSamples = quarter..<(totalSamples - quarter)
      } else {
        uiView.zoomSamples = 0..<totalSamples
      }
    }

    // Handle waveform type
    uiView.waveformType = isLogarithmic ? .logarithmic : .linear
  }

  class Coordinator: NSObject, FDWaveformViewDelegate {
    var onTotalSamplesChanged: ((Int) -> Void)?
    var onRenderComplete: (() -> Void)?
    var lastZoomChangeCounter = 0
    private var startRendering = Date()
    private var startLoading = Date()

    init(onTotalSamplesChanged: ((Int) -> Void)?, onRenderComplete: (() -> Void)?) {
      self.onTotalSamplesChanged = onTotalSamplesChanged
      self.onRenderComplete = onRenderComplete
    }

    func waveformViewWillRender(_ waveformView: FDWaveformView) {
      startRendering = Date()
    }

    func waveformViewDidRender(_ waveformView: FDWaveformView) {
      let elapsed = Date().timeIntervalSince(startRendering)
      NSLog("FDWaveformView rendering done, took %0.3f seconds", elapsed)
      onRenderComplete?()
      UIView.animate(withDuration: 0.25) {
        waveformView.alpha = 1.0
      }
    }

    func waveformViewWillLoad(_ waveformView: FDWaveformView) {
      startLoading = Date()
    }

    func waveformViewDidLoad(_ waveformView: FDWaveformView) {
      let elapsed = Date().timeIntervalSince(startLoading)
      NSLog("FDWaveformView loading done, took %0.3f seconds", elapsed)
      onTotalSamplesChanged?(waveformView.totalSamples)
    }
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
  @State private var isLogarithmic = true
  @State private var totalSamples: Int = 0
  @State private var zoomToMiddle50Percent = false
  @State private var zoomChangeCounter = 0
  @State private var profilingMessage: String?
  @State private var isShowingProfilingAlert = false
  @State private var profilingStartTime: Date?
  @State private var aacRenderTime: TimeInterval?

  var body: some View {
    NavigationView {
      VStack {
        HStack {
          Button("Load AAC") {
            audioURL = nil
            if let url = Bundle.main.url(forResource: "Submarine", withExtension: "aiff") {
              audioURL = url
            }
          }
          .buttonStyle(.borderedProminent)

          Button("Load MP3") {
            audioURL = nil
            if let url = Bundle.main.url(forResource: "Submarine", withExtension: "aiff") {
              audioURL = url
            }
          }
          .buttonStyle(.borderedProminent)
        }

        HStack {
          Button("Randomize Progress") {
            if totalSamples > 0 {
              progress = Int.random(in: 0..<totalSamples)
            }
          }
          .buttonStyle(.bordered)

          Button("Randomize Colors") {
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
            zoomToMiddle50Percent = true
            zoomChangeCounter += 1
          }
          .buttonStyle(.bordered)

          Button("Zoom Out") {
            zoomToMiddle50Percent = false
            zoomChangeCounter += 1
          }
          .buttonStyle(.bordered)
        }

        Picker("Waveform type", selection: $isLogarithmic) {
          Text("Linear").tag(false)
          Text("Logarithmic").tag(true)
        }
        .pickerStyle(.segmented)
        .padding()

        Button("Run Performance Profiling") {
          runPerformanceProfiling()
        }
        .buttonStyle(.borderedProminent)
        .alert("Performance results", isPresented: $isShowingProfilingAlert) {
          Button("OK", role: .cancel) {}
        } message: {
          Text(profilingMessage ?? "")
        }

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
          backgroundColor: $backgroundColor,
          zoomToMiddle50Percent: $zoomToMiddle50Percent,
          isLogarithmic: $isLogarithmic,
          zoomChangeCounter: zoomChangeCounter,
          onTotalSamplesChanged: { samples in
            totalSamples = samples
          },
          onRenderComplete: {
            handleRenderComplete()
          }
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

  private func runPerformanceProfiling() {
    profilingStartTime = Date()
    aacRenderTime = nil

    // Load first file (using Submarine.aiff as AAC equivalent)
    audioURL = nil
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
      if let url = Bundle.main.url(forResource: "Submarine", withExtension: "aiff") {
        audioURL = url
      }
    }
  }

  private func handleRenderComplete() {
    guard let startTime = profilingStartTime else { return }

    if aacRenderTime == nil {
      // First render complete (AAC)
      aacRenderTime = Date().timeIntervalSince(startTime)

      // Load second file
      audioURL = nil
      profilingStartTime = Date()
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        if let url = Bundle.main.url(forResource: "Submarine", withExtension: "aiff") {
          audioURL = url
        }
      }
    } else {
      // Second render complete (MP3)
      let mp3RenderTime = Date().timeIntervalSince(startTime)
      profilingMessage = String(
        format: "AAC: %.3f seconds\nMP3: %.3f seconds",
        aacRenderTime ?? 0,
        mp3RenderTime
      )
      isShowingProfilingAlert = true
      profilingStartTime = nil
    }
  }
}

#Preview {
  ContentView()
}
