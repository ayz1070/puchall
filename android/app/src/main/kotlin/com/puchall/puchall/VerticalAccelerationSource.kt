package com.puchall.puchall

import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import kotlin.math.sqrt

/**
 * 중력이 제거된 "수직 선형 가속도"(m/s², 위쪽이 양수)를 만들어 내보낸다.
 *
 * 원시 가속도 magnitude(`sqrt(x²+y²+z²)`)는 회전 불변이라 폰 방향에 무관한 대신
 * 위/아래를 구분하지 못하고, 정지 상태에서도 중력 때문에 9.81이 깔린다.
 * 여기서는 중력 벡터에 선형 가속도를 투영해, 폰 방향과는 무관하면서도
 * 부호로 방향을 알 수 있는 값을 만든다.
 *
 * 측정과 기준치 캘리브레이션이 **같은 신호**를 보도록 두 경로 모두 이 클래스를 쓴다.
 *
 * 타임스탬프는 `SensorEvent.timestamp`(부팅 기준 나노초)에서 얻는다. 수신 시각이 아니라
 * 센서가 실제로 값을 읽은 시각이므로, 화면이 꺼져 이벤트가 몰려 전달되어도
 * 반복 간격 판정이 무너지지 않는다. 절대 시각이 아니므로 간격 계산에만 쓴다.
 */
class VerticalAccelerationSource(
    private val sensorManager: SensorManager,
    private val onSample: (verticalAcceleration: Double, timestampMs: Long) -> Unit,
) : SensorEventListener {

    private var gravityX = 0.0
    private var gravityY = 0.0
    private var gravityZ = 0.0
    private var hasGravity = false
    private var usesFallback = false

    fun start() {
        val linearAcceleration = sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
        val gravity = sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)

        if (linearAcceleration != null && gravity != null) {
            usesFallback = false
            sensorManager.registerListener(this, gravity, SAMPLING_PERIOD_US)
            sensorManager.registerListener(this, linearAcceleration, SAMPLING_PERIOD_US)
            return
        }

        // 합성 센서가 없는 기기: 원시 가속도에서 중력을 저역통과로 추정해 빼낸다.
        usesFallback = true
        hasGravity = false
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.also {
            sensorManager.registerListener(this, it, SAMPLING_PERIOD_US)
        }
    }

    fun stop() {
        sensorManager.unregisterListener(this)
        hasGravity = false
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    override fun onSensorChanged(event: SensorEvent) {
        val timestampMs = event.timestamp / 1_000_000L

        when (event.sensor.type) {
            Sensor.TYPE_GRAVITY -> {
                gravityX = event.values.getOrElse(0) { 0f }.toDouble()
                gravityY = event.values.getOrElse(1) { 0f }.toDouble()
                gravityZ = event.values.getOrElse(2) { 0f }.toDouble()
                hasGravity = true
            }

            Sensor.TYPE_LINEAR_ACCELERATION -> {
                emitVertical(
                    event.values.getOrElse(0) { 0f }.toDouble(),
                    event.values.getOrElse(1) { 0f }.toDouble(),
                    event.values.getOrElse(2) { 0f }.toDouble(),
                    timestampMs,
                )
            }

            Sensor.TYPE_ACCELEROMETER -> {
                if (!usesFallback) return
                handleFallbackAcceleration(
                    event.values.getOrElse(0) { 0f }.toDouble(),
                    event.values.getOrElse(1) { 0f }.toDouble(),
                    event.values.getOrElse(2) { 0f }.toDouble(),
                    timestampMs,
                )
            }
        }
    }

    private fun handleFallbackAcceleration(x: Double, y: Double, z: Double, timestampMs: Long) {
        if (!hasGravity) {
            gravityX = x
            gravityY = y
            gravityZ = z
            hasGravity = true
            return
        }

        gravityX += GRAVITY_EMA_ALPHA * (x - gravityX)
        gravityY += GRAVITY_EMA_ALPHA * (y - gravityY)
        gravityZ += GRAVITY_EMA_ALPHA * (z - gravityZ)

        emitVertical(x - gravityX, y - gravityY, z - gravityZ, timestampMs)
    }

    private fun emitVertical(x: Double, y: Double, z: Double, timestampMs: Long) {
        if (!hasGravity) return

        val gravityMagnitude = sqrt(gravityX * gravityX + gravityY * gravityY + gravityZ * gravityZ)
        if (gravityMagnitude < MIN_GRAVITY_MAGNITUDE) return

        // TYPE_GRAVITY 벡터는 하늘 쪽을 가리킨다(정지 시 가속도계 값과 동일).
        // 따라서 내적이 양수면 위쪽으로 가속하는 중이다.
        val vertical = (x * gravityX + y * gravityY + z * gravityZ) / gravityMagnitude
        onSample(vertical, timestampMs)
    }

    companion object {
        /** 50Hz. SENSOR_DELAY_GAME과 같은 간격을 명시적으로 고정한다. */
        const val SAMPLING_PERIOD_US = 20_000

        /** 약 0.16Hz 차단. 중력만 남기고 동작 성분은 걸러 내기 위한 값. */
        private const val GRAVITY_EMA_ALPHA = 0.02

        private const val MIN_GRAVITY_MAGNITUDE = 1e-3
    }
}
