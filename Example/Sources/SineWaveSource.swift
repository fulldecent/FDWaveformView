//
//  SineWaveSource.swift
//  Example
//
//  A procedural audio source that generates a sine wave for demo purposes.
//

import FDWaveformView
import Foundation

/// A procedural audio source that generates a sine wave.
///
/// This source generates a 440Hz sine wave with amplitude modulation:
/// the amplitude ramps from 0 to 1 and back to 0 over each second,
/// creating a pulsing effect.
final class SineWaveSource: FDWaveformDataSource {

    /// The frequency of the sine wave in Hz.
    let frequency: Double

    /// Duration of the generated audio in seconds.
    let duration: Double

    /// Sample rate in samples per second.
    let sampleRate: Double

    /// Number of audio channels (always 1 for procedural sources).
    let channelCount: Int = 1

    /// Total number of samples.
    var sampleCount: Int {
        Int(duration * sampleRate)
    }

    /// Period of the amplitude modulation in seconds.
    /// The amplitude goes from 0 → 1 → 0 over this period.
    let modulationPeriod: Double

    /// Creates a sine wave audio source.
    ///
    /// - Parameters:
    ///   - frequency: Frequency of the sine wave in Hz. Default is 440Hz (A4 note).
    ///   - duration: Duration of the audio in seconds. Default is 10 seconds.
    ///   - sampleRate: Sample rate in samples per second. Default is 44100Hz.
    ///   - modulationPeriod: Period of amplitude modulation in seconds. Default is 1 second.
    init(
        frequency: Double = 440.0,
        duration: Double = 10.0,
        sampleRate: Double = 44100.0,
        modulationPeriod: Double = 1.0
    ) {
        self.frequency = frequency
        self.duration = duration
        self.sampleRate = sampleRate
        self.modulationPeriod = modulationPeriod
    }

    func readSamples(in range: Range<Int>) throws -> [Float] {
        guard range.lowerBound >= 0 && range.upperBound <= sampleCount else {
            throw FDWaveformDataSourceError.rangeOutOfBounds
        }

        guard !range.isEmpty else { return [] }

        let count = range.count
        var samples = [Float](repeating: 0.0, count: count)

        // Generate sine wave with amplitude modulation
        let twoPi = Float.pi * 2.0
        let freqFloat = Float(frequency)
        let sampleRateFloat = Float(sampleRate)
        let modulationSamples = Float(modulationPeriod * sampleRate)

        for i in 0..<count {
            let sampleIndex = Float(range.lowerBound + i)

            // Generate sine wave: sin(2π * frequency * t)
            let phase = twoPi * freqFloat * sampleIndex / sampleRateFloat
            let sineValue = sin(phase)

            // Calculate amplitude modulation (triangle wave from 0 to 1 to 0)
            // Position within the modulation period [0, 1)
            let modPosition =
                (sampleIndex.truncatingRemainder(dividingBy: modulationSamples)) / modulationSamples

            // Triangle wave: 0→1 for first half, 1→0 for second half
            let amplitude: Float
            if modPosition < 0.5 {
                amplitude = modPosition * 2.0  // 0 to 1
            } else {
                amplitude = (1.0 - modPosition) * 2.0  // 1 to 0
            }

            samples[i] = sineValue * amplitude
        }

        return samples
    }
}
