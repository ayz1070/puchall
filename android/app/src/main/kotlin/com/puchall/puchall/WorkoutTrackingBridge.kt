package com.puchall.puchall

import io.flutter.plugin.common.EventChannel

object WorkoutTrackingBridge {
    private var eventSink: EventChannel.EventSink? = null
    private var lastState: Map<String, Any?> = WorkoutTrackingService.idleState()

    fun setEventSink(sink: EventChannel.EventSink?) {
        eventSink = sink
        sink?.success(lastState)
    }

    fun emit(state: Map<String, Any?>) {
        lastState = state
        eventSink?.success(state)
    }

    fun currentState(): Map<String, Any?> = lastState
}
