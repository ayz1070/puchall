package com.puchall.puchall

import io.flutter.plugin.common.EventChannel

object WorkoutTrackingBridge {
    private var eventSink: EventChannel.EventSink? = null
    private var lastState: Map<String, Any?> = WorkoutTrackingService.idleState()

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        sink?.success(taggedState(lastState))
    }

    fun emit(state: Map<String, Any?>) {
        lastState = state
        eventSink?.success(taggedState(state))
    }

    /**
     * 기준치 캘리브레이션 중에만 흐르는 원시 수직 가속도 샘플.
     * 측정 상태 이벤트와 같은 채널을 쓰므로 `type`으로 구분한다.
     */
    fun emitCalibrationSample(verticalAcceleration: Double, timestampMs: Long) {
        eventSink?.success(
            mapOf(
                "type" to TYPE_CALIBRATION_SAMPLE,
                "verticalAcceleration" to verticalAcceleration,
                "timestampMs" to timestampMs,
            ),
        )
    }

    fun currentState(): Map<String, Any?> = lastState

    private fun taggedState(state: Map<String, Any?>): Map<String, Any?> {
        return state + ("type" to TYPE_STATE)
    }

    private const val TYPE_STATE = "state"
    private const val TYPE_CALIBRATION_SAMPLE = "calibrationSample"
}
