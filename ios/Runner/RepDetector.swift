import Foundation

struct RepDetectorConfig {
    static let defaultLowPassCutoffHz = 2.5

    let amplitudeThreshold: Double
    let minHalfPeriodMs: Double
    let maxHalfPeriodMs: Double
    let cooldownMs: Double
    let lowPassCutoffHz: Double

    init(
        amplitudeThreshold: Double,
        minHalfPeriodMs: Double,
        maxHalfPeriodMs: Double,
        cooldownMs: Double,
        lowPassCutoffHz: Double = RepDetectorConfig.defaultLowPassCutoffHz
    ) {
        self.amplitudeThreshold = amplitudeThreshold
        self.minHalfPeriodMs = minHalfPeriodMs
        self.maxHalfPeriodMs = maxHalfPeriodMs
        self.cooldownMs = cooldownMs
        self.lowPassCutoffHz = lowPassCutoffHz
    }
}

/// 중력이 제거된 수직 가속도 시계열에서 반복을 센다.
///
/// Dart 쪽 `rep_detector.dart`, Kotlin 쪽 `RepDetector.kt`와 동일한 알고리즘이다.
/// Dart 구현이 골든 테스트로 검증되는 명세이므로, 한쪽을 고치면 세 곳을 모두 맞춰야 한다.
///
/// 아래로 내려갔다가(-임계값 통과) 위로 올라오는(+임계값 통과) 한 쌍을 반복 1회로 본다.
final class RepDetector {
    private enum Phase {
        case waitingForValley
        case waitingForPeak
    }

    private let config: RepDetectorConfig

    private var filteredValue: Double?
    private var filterTimestampMs: Double?
    private var phase: Phase = .waitingForValley
    private var valleyTimestampMs: Double?
    private var valleyValue: Double = 0
    private var lastCountedAtMs: Double?

    private(set) var count: Int = 0

    init(config: RepDetectorConfig) {
        self.config = config
    }

    /// 샘플 하나를 넣고, 이 샘플에서 반복이 완성되면 true를 돌려준다.
    @discardableResult
    func update(verticalAcceleration: Double, timestampMs: Double) -> Bool {
        let value = lowPass(raw: verticalAcceleration, timestampMs: timestampMs)

        switch phase {
        case .waitingForValley:
            if value <= -config.amplitudeThreshold {
                phase = .waitingForPeak
                valleyTimestampMs = timestampMs
                valleyValue = value
            }
            return false

        case .waitingForPeak:
            if value < valleyValue {
                valleyValue = value
            }

            guard let valleyAt = valleyTimestampMs else { return false }
            let elapsedMs = timestampMs - valleyAt

            if elapsedMs > config.maxHalfPeriodMs {
                // 내려간 뒤 제때 올라오지 않았다. 반복으로 보지 않는다.
                phase = .waitingForValley
                return false
            }

            if value < config.amplitudeThreshold { return false }

            phase = .waitingForValley

            if elapsedMs < config.minHalfPeriodMs { return false }

            if let lastCountedAt = lastCountedAtMs,
               timestampMs - lastCountedAt < config.cooldownMs {
                return false
            }

            lastCountedAtMs = timestampMs
            count += 1
            return true
        }
    }

    func reset() {
        filteredValue = nil
        filterTimestampMs = nil
        phase = .waitingForValley
        valleyTimestampMs = nil
        valleyValue = 0
        lastCountedAtMs = nil
        count = 0
    }

    /// 시간 상수 기반 1차 저역통과 필터.
    private func lowPass(raw: Double, timestampMs: Double) -> Double {
        guard let previousValue = filteredValue, let previousTimestampMs = filterTimestampMs else {
            filteredValue = raw
            filterTimestampMs = timestampMs
            return raw
        }

        let deltaSeconds = (timestampMs - previousTimestampMs) / 1000.0
        if deltaSeconds <= 0 { return previousValue }

        let tau = 1.0 / (2.0 * Double.pi * config.lowPassCutoffHz)
        let alpha = deltaSeconds / (tau + deltaSeconds)
        let filtered = previousValue + alpha * (raw - previousValue)

        filteredValue = filtered
        filterTimestampMs = timestampMs
        return filtered
    }
}
