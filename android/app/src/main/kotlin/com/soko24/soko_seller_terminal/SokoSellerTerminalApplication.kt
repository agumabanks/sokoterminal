package com.soko24.soko_seller_terminal

import android.app.Application
import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Build

/**
 * Custom Application class that creates Android notification channels on startup.
 *
 * Channels created:
 * - orders_channel (IMPORTANCE_HIGH)   : New marketplace orders and order updates
 * - sync_channel   (IMPORTANCE_DEFAULT): Background sync status and alerts
 * - general_channel(IMPORTANCE_DEFAULT): General notifications and alerts
 *
 * These channels must exist before any FCM notification with a channel ID is received.
 */
class SokoSellerTerminalApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) {
            return
        }

        val channels = listOf(
            NotificationChannel(
                CHANNEL_ORDERS,
                "Orders",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "New marketplace orders and order updates"
                enableVibration(true)
            },
            NotificationChannel(
                CHANNEL_SYNC,
                "Sync Updates",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "Background sync status and alerts"
            },
            NotificationChannel(
                CHANNEL_GENERAL,
                "General",
                NotificationManager.IMPORTANCE_DEFAULT,
            ).apply {
                description = "General notifications and alerts"
            },
        )

        val notificationManager = getSystemService(NotificationManager::class.java)
        notificationManager.createNotificationChannels(channels)
    }

    companion object {
        const val CHANNEL_ORDERS = "orders_channel"
        const val CHANNEL_SYNC = "sync_channel"
        const val CHANNEL_GENERAL = "general_channel"
    }
}
