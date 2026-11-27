package cm.naxa.naxaservices.auth

/** Only an explicit authentication/authorization rejection invalidates remembered credentials. */
internal fun discardRememberedSession(status: Int?): Boolean = status == 401 || status == 403

/** Explicit HTTP rejections never authorize local recovery. */
internal fun isTemporarySessionFailure(status:Int?):Boolean = status==null || status==408 || status==429 || status in 500..599
