package cm.naxa.naxaservices

import android.app.Application
import cm.naxa.core.notifications.NotificationChannels

class NaxaServicesApplication : Application() {
    override fun onCreate() {
        super.onCreate()
        FirebasePushClient.initialize(this)
        NotificationChannels.create(this)
    }
}

