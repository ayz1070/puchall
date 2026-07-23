package com.puchall.puchall

class WorkoutCounter(
    private val threshold: Double,
    private val gyroscopeThreshold: Double,
    private val releaseRatio: Double,
    private val cooldownMs: Long,
) {
    private var canCount = true
    private var lastCountedAtMillis: Long? = null

    fun update(
        accelerationMagnitude: Double,
        gyroscopeMagnitude: Double,
        timestampMillis: Long = System.currentTimeMillis(),
    ): Boolean {
        val hasRecovered = accelerationMagnitude < threshold * releaseRatio
        val passedAcceleration = accelerationMagnitude >= threshold
        val passedGyroscope = gyroscopeThreshold <= 0 || gyroscopeMagnitude >= gyroscopeThreshold
        val lastCountedAt = lastCountedAtMillis
        val passedCooldown = lastCountedAt == null || timestampMillis - lastCountedAt >= cooldownMs

        if (canCount && passedCooldown && passedAcceleration && passedGyroscope) {
            canCount = false
            lastCountedAtMillis = timestampMillis
            return true
        }

        if (!canCount && hasRecovered) {
            canCount = true
        }

        return false
    }

    fun reset() {
        canCount = true
        lastCountedAtMillis = null
    }
}
