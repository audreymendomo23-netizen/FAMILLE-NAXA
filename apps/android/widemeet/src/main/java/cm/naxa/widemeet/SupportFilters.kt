package cm.naxa.widemeet

/** Only match already-authorized list metadata; null subjects stay masked. */
internal fun supportMatches(status:String,category:String,subject:String?,statusFilter:String,categoryFilter:String,query:String):Boolean =
 (statusFilter=="all" || status==statusFilter) &&
 (categoryFilter=="all" || category==categoryFilter) &&
 (subject.orEmpty().contains(query.trim(),ignoreCase=true))
