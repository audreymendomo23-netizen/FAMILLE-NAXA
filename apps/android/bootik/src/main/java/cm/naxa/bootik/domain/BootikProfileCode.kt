package cm.naxa.bootik.domain

/**
 * Stable identifiers stored in local and remote data. Display labels belong to
 * Android string resources and must never be persisted in place of these codes.
 */
enum class BootikUniverseCode(val code: String) {
    RETAILER("retailer"),
    DISTRIBUTOR("distributor")
}

enum class RetailProfileCode(val code: String) {
    BOUTIQUE("boutique"),
    SUPERETTE("superette"),
    POISSONNERIE("poissonnerie"),
    BOULANGERIE("boulangerie"),
    SHOPPING("shopping"),
    ALIMENTATION("alimentation"),
    CAVE("cave"),
    QUINCAILLERIE("quincaillerie"),
    PARFUMERIE("parfumerie"),
    BOUCHERIE("boucherie"),
    FERME("ferme"),
    DEPOT_GAZ("depot_gaz"),
    SUPERMARCHE("supermarche"),
    BROCANTE("brocante");

    companion object {
        fun fromCode(code: String): RetailProfileCode? =
            entries.firstOrNull { it.code == code }
    }
}

/** Reserved for the second delivery universe. Not selectable in the retail-first V1.1 shell. */
enum class DistributorProfileCode(val code: String) {
    BOISSONS_BRASSERIES("boissons_brasseries"),
    GAZ_ENERGIE("gaz_energie"),
    ALIMENTAIRE_FMCG("alimentaire_fmcg"),
    FRAIS_SURGELES("frais_surgeles"),
    HYGIENE_ENTRETIEN("hygiene_entretien"),
    BEAUTE_SOINS("beaute_soins"),
    IMPORTATEUR_MARQUES("importateur_marques"),
    AGRO_INTRANTS("agro_intrants");

    companion object {
        fun fromCode(code: String): DistributorProfileCode? =
            entries.firstOrNull { it.code == code }
    }
}
