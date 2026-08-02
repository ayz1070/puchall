package com.puchall.puchall

import kotlin.math.PI

class RepDetectorConfig(
    val amplitudeThreshold: Double,
    val minHalfPeriodMs: Long,
    val maxHalfPeriodMs: Long,
    val cooldownMs: Long,
    val lowPassCutoffHz: Double = DEFAULT_LOW_PASS_CUTOFF_HZ,
) {
    companion object {
        const val DEFAULT_LOW_PASS_CUTOFF_HZ = 2.5
    }
}

/**
 * 중력이 제거된 수직 가속도 시계열에서 반복을 센다.
 *
 * Dart 쪽 `rep_detector.dart`와 동일한 알고리즘이다. 백그라운드 측정을 위해
 * 카운팅은 네이티브에서 돌아야 하므로 구현이 두 벌 존재하며, Dart 구현이
 * 골든 테스트로 검증되는 명세 역할을 한다. 한쪽을 고치면 반드시 다른 쪽도 맞춰야 한다.
 *
 * 아래로 내려갔다가(-임계값 통과) 위로 올라오는(+임계값 통과) 한 쌍을 반복 1회로 본다.
 * 0 근처의 잡음은 양쪽 임계값을 모두 통과할 수 없으므로 카운트되지 않는다.
 */
class RepDetector(private val config: RepDetectorConfig) {

    private enum class Phase { WAITING_FOR_VALLEY, WAITING_FOR_PEAK }

    private var filteredValue: Double? = null
    private var filterTimestampMs: Long? = null
    private var phase = Phase.WAITING_FOR_VALLEY
    private var valleyTimestampMs: Long? = null
    private var valleyValue = 0.0
    private var lastCountedAtMs: Long? = null

    var count: Int = 0
        private set

    /** 샘플 하나를 넣고, 이 샘플에서 반복이 완성되면 true를 돌려준다. */
    fun update(verticalAcceleration: Double, timestampMs: Long): Boolean {
        val value = lowPass(verticalAcceleration, timestampMs)

        when (phase) {
            Phase.WAITING_FOR_VALLEY -> {
                if (value <= -config.amplitudeThreshold) {
                    phase = Phase.WAITING_FOR_PEAK
                    valleyTimestampMs = timestampMs
                    valleyValue = value
                }
                return false
            }

            Phase.WAITING_FOR_PEAK -> {
                if (value < valleyValue) {
                    valleyValue = value
                }

                val valleyAt = valleyTimestampMs ?: return false
                val elapsedMs = timestampMs - valleyAt

                if (elapsedMs > config.maxHalfPeriodMs) {
                    // 내려간 뒤 제때 올라오지 않았다. 반복으로 보지 않는다.
                    phase = Phase.WAITING_FOR_VALLEY
                    return false
                }

                if (value < config.amplitudeThreshold) return false

                phase = Phase.WAITING_FOR_VALLEY

                if (elapsedMs < config.minHalfPeriodMs) return false

                val lastCountedAt = lastCountedAtMs
                if (lastCountedAt != null && timestampMs - lastCountedAt < config.cooldownMs) {
                    return false
                }

                lastCountedAtMs = timestampMs
                count += 1
                return true
            }
        }
    }

    fun reset() {
        filteredValue = null
        filterTimestampMs = null
        phase = Phase.WAITING_FOR_VALLEY
        valleyTimestampMs = null
        valleyValue = 0.0
        lastCountedAtMs = null
        count = 0
    }

    /**
     * 시간 상수 기반 1차 저역통과 필터.
     * 샘플 간격에서 계수를 매번 구하므로 샘플이 몰려 들어와도 차단 주파수가 유지된다.
     */
    private fun lowPass(raw: Double, timestampMs: Long): Double {
        val previousValue = filteredValue
        val previousTimestampMs = filterTimestampMs

        if (previousValue == null || previousTimestampMs == null) {
            filteredValue = raw
            filterTimestampMs = timestampMs
            return raw
        }

        val deltaSeconds = (timestampMs - previousTimestampMs) / 1000.0
        if (deltaSeconds <= 0.0) return previousValue

        val tau = 1.0 / (2.0 * PI * config.lowPassCutoffHz)
        val alpha = deltaSeconds / (tau + deltaSeconds)
        val filtered = previousValue + alpha * (raw - previousValue)

        filteredValue = filtered
        filterTimestampMs = timestampMs
        return filtered
    }
}
