//
// Copyright William Entriken and the FDWaveformView contributors.
//

import Accelerate
import UIKit

/// The type of amplitude processing for waveform rendering.
///
/// This determines how audio sample amplitudes are transformed before display:
/// - `.linear`: Direct amplitude mapping (quiet sounds may be hard to see)
/// - `.logarithmic`: Decibel scale (better visibility of quiet sounds)
public enum FDWaveformType: Equatable {
    /// Waveform is rendered using a linear scale.
    /// Amplitudes are displayed proportionally to their actual values.
    case linear

    /// Waveform is rendered using a logarithmic (decibel) scale.
    /// - Parameter noiseFloor: The "zero" level in dB (e.g., -50 dB).
    ///   Samples quieter than this are displayed as silence.
    case logarithmic(noiseFloor: CGFloat)

    public static func == (lhs: FDWaveformType, rhs: FDWaveformType) -> Bool {
        switch lhs {
        case .linear:
            if case .linear = rhs {
                return true
            }
        case .logarithmic(let lhsNoiseFloor):
            if case .logarithmic(let rhsNoiseFloor) = rhs {
                return lhsNoiseFloor == rhsNoiseFloor
            }
        }
        return false
    }

    /// The floor value for this waveform type.
    /// For linear, this is 0. For logarithmic, this is the noise floor.
    public var floorValue: CGFloat {
        switch self {
        case .linear: return 0
        case .logarithmic(let noiseFloor): return noiseFloor
        }
    }

    /// Process samples according to this waveform type.
    ///
    /// For linear, samples pass through unchanged.
    /// For logarithmic, samples are converted to decibels and clipped to the noise floor.
    ///
    /// - Parameter normalizedSamples: Samples in range 0...1 (absolute amplitude).
    ///   Modified in place.
    public func process(normalizedSamples: inout [Float]) {
        switch self {
        case .linear:
            return

        case .logarithmic(let noiseFloor):
            // Convert samples to a log scale
            var zero: Float = 32768.0
            vDSP_vdbcon(
                normalizedSamples, 1, &zero, &normalizedSamples, 1,
                vDSP_Length(normalizedSamples.count), 1)

            // Clip to [noiseFloor, 0]
            var ceil: Float = 0.0
            var noiseFloorFloat = Float(noiseFloor)
            vDSP_vclip(
                normalizedSamples, 1, &noiseFloorFloat, &ceil, &normalizedSamples, 1,
                vDSP_Length(normalizedSamples.count))
        }
    }
}
