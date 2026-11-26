package cm.naxa.naxaservices.auth

/** Only an explicit authentication/authorization rejection invalidates remembered credentials. */
internal fun discardRememberedSession(status: Int?): Boolean = status == 401 || status == 403
