package com.example.sih

import java.util.Collections

// Represents a single 100ms frame of your ride
data class TelemetryFrame(
    val rpm: Float,
    val gear: Int,
    val speed: Float,
    val throttle: Float,
    val leanAngle: Float
)

object TripDataStore {
    val tripLog: MutableList<TelemetryFrame> = Collections.synchronizedList(mutableListOf<TelemetryFrame>())

    @Synchronized
    fun clear() {
        tripLog.clear()
    }
}