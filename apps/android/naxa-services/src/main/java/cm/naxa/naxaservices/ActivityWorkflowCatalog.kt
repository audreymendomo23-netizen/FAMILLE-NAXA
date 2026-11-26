package cm.naxa.naxaservices

import java.time.LocalDate

internal enum class ActivityFieldKind { TEXT, TEXTAREA, NUMBER, DATE, SELECT }

internal data class ActivityFieldOption(val value: String, val labelFr: String, val labelEn: String)

internal data class ActivityFieldDefinition(
    val key: String,
    val labelFr: String,
    val labelEn: String,
    val required: Boolean,
    val kind: ActivityFieldKind = ActivityFieldKind.TEXT,
    val options: List<ActivityFieldOption> = emptyList(),
    val min: Long? = null,
    val max: Long? = null,
    val maxLength: Int = 500,
    val helpFr: String? = null
)

internal data class ActivityStageDefinition(
    val code: String,
    val labelFr: String,
    val labelEn: String,
    val next: List<String>
)

internal data class ActivityWorkflowDefinition(
    val profile: String,
    val titleFr: String,
    val titleEn: String,
    val purposeFr: String,
    val purposeEn: String,
    val recordType: String,
    val journey: String,
    val fields: List<ActivityFieldDefinition>,
    val stages: List<ActivityStageDefinition>,
    val sharedModules: List<String>,
    val notesFr: List<String>
) {
    fun stage(code: String): ActivityStageDefinition? = stages.firstOrNull { it.code == code }
    fun nextStages(code: String): List<ActivityStageDefinition> =
        stage(if (code == "open") "received" else code)?.next.orEmpty().mapNotNull(::stage)
    fun terminalStatus(): String = if (profile == "pressing") "picked_up" else "closed"
}

internal object ActivityWorkflows {
    private fun option(value: String, fr: String, en: String = fr) = ActivityFieldOption(value, fr, en)
    private fun text(key: String, fr: String, en: String, required: Boolean = false, maxLength: Int = 500) =
        ActivityFieldDefinition(key, fr, en, required, maxLength = maxLength)
    private fun area(key: String, fr: String, en: String, required: Boolean = false, maxLength: Int = 1000, help: String? = null) =
        ActivityFieldDefinition(key, fr, en, required, ActivityFieldKind.TEXTAREA, maxLength = maxLength, helpFr = help)
    private fun number(key: String, fr: String, en: String, required: Boolean = false, min: Long? = null, max: Long? = null) =
        ActivityFieldDefinition(key, fr, en, required, ActivityFieldKind.NUMBER, min = min, max = max)
    private fun date(key: String, fr: String, en: String, required: Boolean = false) =
        ActivityFieldDefinition(key, fr, en, required, ActivityFieldKind.DATE)
    private fun select(
        key: String, fr: String, en: String, required: Boolean = false,
        options: List<ActivityFieldOption>
    ) = ActivityFieldDefinition(key, fr, en, required, ActivityFieldKind.SELECT, options = options)
    private fun stage(code: String, fr: String, en: String, vararg next: String) =
        ActivityStageDefinition(code, fr, en, next.toList())

    val all: List<ActivityWorkflowDefinition> = listOf(
        ActivityWorkflowDefinition(
            profile = "pressing",
            titleFr = "Pressing & blanchisserie", titleEn = "Laundry & dry cleaning",
            purposeFr = "Dépôt textile individualisé, ticket, traitement, contrôle, retrait et suivi des pièces non retirées.",
            purposeEn = "Individual garment intake, ticket, treatment, quality check, collection and uncollected-item follow-up.",
            recordType = "pressing_order", journey = "deposit",
            fields = listOf(
                text("garments", "Pièces déposées et quantités", "Garments and quantities", true),
                area("care", "Traitement, textiles et précautions", "Treatment, textiles and care instructions", true),
                area("stains", "Taches, défauts constatés et réserves", "Stains, observed defects and reservations"),
                date("promised_at", "Date promise de retrait", "Promised collection date", true),
                number("deposit", "Acompte demandé (FCFA)", "Requested deposit (XAF)", min = 0)
            ),
            stages = listOf(
                stage("received", "Reçu", "Received", "in_progress"),
                stage("in_progress", "En traitement", "Processing", "ready"),
                stage("ready", "Prêt", "Ready for collection", "picked_up"),
                stage("picked_up", "Retiré", "Collected")
            ),
            sharedModules = listOf("customers", "agenda", "cash", "stock", "team", "reports"),
            notesFr = listOf("Ticket par dépôt, pièces et anomalies visibles", "Acompte et retrait suivent les règles de caisse et de preuve de paiement", "Conservation et relances doivent être paramétrées par le commerçant")
        ),
        ActivityWorkflowDefinition(
            profile = "coiffure",
            titleFr = "Coiffure & salon", titleEn = "Hair salon",
            purposeFr = "Prestation planifiée par coiffeur et fauteuil, avec style, consignes, consommables et clôture.",
            purposeEn = "Appointment by stylist and chair, including style, customer instructions, consumables and close-out.",
            recordType = "service_order", journey = "service",
            fields = listOf(
                select("style", "Style, coupe ou coiffure", "Style, cut or hairstyle", true, listOf(
                    option("coupe", "Coupe", "Haircut"), option("tresses", "Tresses / nattes", "Braids"),
                    option("locks", "Locks", "Locs"), option("coloration", "Coloration", "Coloring"),
                    option("brushing", "Brushing"), option("soin", "Soin capillaire", "Hair treatment"),
                    option("autre", "Autre", "Other")
                )),
                area("technique", "Technique, longueur et consignes client", "Technique, length and customer instructions", true, 1000),
                text("provider", "Coiffeur / prestataire affecté", "Assigned stylist / provider"),
                text("workstation", "Fauteuil ou poste", "Chair or workstation"),
                area("products", "Produits et accessoires consommés", "Products and accessories used", false, 700)
            ),
            stages = listOf(
                stage("received", "Accueil", "Intake", "approved", "cancelled"),
                stage("approved", "Prestation confirmée", "Service confirmed", "in_progress"),
                stage("in_progress", "Prestation en cours", "Service in progress", "quality_check"),
                stage("quality_check", "Vérification finale", "Final check", "ready"),
                stage("ready", "Prête", "Ready", "delivered"),
                stage("delivered", "Remise au client", "Handed to customer", "closed"),
                stage("closed", "Clôturée", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "agenda", "services", "workstations", "cash", "stock", "team", "loyalty", "reports"),
            notesFr = listOf("Rendez-vous, durée, fauteuil et prestataire sont gérés dans l'agenda partagé", "Commissions calculées uniquement selon une règle de rémunération validée")
        ),
        ActivityWorkflowDefinition(
            profile = "couture",
            titleFr = "Couture & retouche", titleEn = "Tailoring & alterations",
            purposeFr = "Commande textile avec mensurations, tissu, essayage, retouches, contrôle et livraison.",
            purposeEn = "Garment order with measurements, fabric, fitting, alterations, quality check and delivery.",
            recordType = "work_order", journey = "production",
            fields = listOf(
                text("garment", "Vêtement, modèle ou retouche", "Garment, design or alteration", true),
                area("measurements", "Mensurations et consignes de coupe", "Measurements and cutting instructions", true, 1200, "Consigner uniquement les mesures nécessaires à cette commande et limiter leur accès."),
                area("fabric", "Tissu, fournitures et accessoires", "Fabric, supplies and accessories", false, 700),
                date("fitting", "Date d'essayage", "Fitting date"),
                date("delivery", "Date de livraison souhaitée", "Preferred delivery date")
            ),
            stages = listOf(
                stage("received", "Commande reçue", "Order received", "measurement", "diagnostic", "cancelled"),
                stage("measurement", "Prise des mensurations", "Measurements", "quote_pending", "fitting", "cancelled"),
                stage("diagnostic", "Étude du modèle / retouche", "Design / alteration review", "quote_pending", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Commande validée", "Order approved", "waiting_parts", "in_progress"),
                stage("waiting_parts", "Tissu / fournitures attendus", "Waiting for fabric / supplies", "in_progress"),
                stage("in_progress", "Confection / retouche", "Making / alteration", "quality_check"),
                stage("quality_check", "Contrôle / essayage", "Quality check / fitting", "fitting", "ready"),
                stage("fitting", "Essayage / ajustement", "Fitting / adjustment", "in_progress", "ready"),
                stage("ready", "Prête", "Ready", "delivered"),
                stage("delivered", "Livrée", "Delivered", "closed"),
                stage("closed", "Clôturée", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "agenda", "stock", "purchases", "cash", "team", "reports"),
            notesFr = listOf("Les mensurations sont limitées au dossier de commande et soumises à des droits adaptés", "L'essayage peut entraîner un retour en retouche avant validation")
        ),
        ActivityWorkflowDefinition(
            profile = "beaute",
            titleFr = "Beauté & esthétique", titleEn = "Beauty & aesthetics",
            purposeFr = "Soin esthétique planifié par cabine et prestataire, avec protocole commercial et produits utilisés.",
            purposeEn = "Beauty service scheduled by room and provider, with non-medical service protocol and products used.",
            recordType = "service_order", journey = "service",
            fields = listOf(
                select("treatment", "Soin, formule ou prestation", "Treatment or service", true, listOf(
                    option("soin_visage", "Soin visage", "Facial"), option("soin_corps", "Soin du corps", "Body treatment"),
                    option("manucure", "Manucure", "Manicure"), option("pedicure", "Pédicure", "Pedicure"),
                    option("maquillage", "Maquillage", "Make-up"), option("epilation", "Épilation", "Hair removal"),
                    option("massage_bien_etre", "Massage bien-être", "Wellness massage"), option("autre", "Autre", "Other")
                )),
                area("protocol", "Protocole et consignes non médicales", "Non-medical protocol and instructions", true, 1000, "Ne pas consigner de diagnostic, d'antécédent ni de donnée médicale."),
                text("provider", "Esthéticienne / prestataire", "Beautician / provider"),
                text("room", "Cabine ou poste requis", "Required room or workstation"),
                area("products", "Produits et consommables utilisés", "Products and consumables used", false, 700)
            ),
            stages = listOf(
                stage("received", "Accueil", "Intake", "approved", "cancelled"),
                stage("approved", "Soin confirmé", "Treatment confirmed", "in_progress"),
                stage("in_progress", "Soin en cours", "Treatment in progress", "quality_check"),
                stage("quality_check", "Vérification finale", "Final check", "ready"),
                stage("ready", "Terminé", "Completed", "delivered"),
                stage("delivered", "Remis au client", "Handed to customer", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "agenda", "services", "workstations", "cash", "stock", "team", "loyalty", "reports"),
            notesFr = listOf("Ne pas collecter de diagnostic, antécédent ou donnée médicale dans ce dossier métier", "Les consignes de confort restent factuelles et limitées au besoin de prestation")
        ),
        ActivityWorkflowDefinition(
            profile = "parfumerie",
            titleFr = "Parfumerie & commerce spécialisé", titleEn = "Perfume & specialty retail",
            purposeFr = "Commerce produit : variantes, références, conditionnements, stock, fournisseurs, commandes spéciales et ventes.",
            purposeEn = "Product retail: variants, references, pack sizes, stock, suppliers, special orders and sales.",
            recordType = "retail", journey = "retail",
            fields = listOf(
                text("product", "Produit, marque ou référence", "Product, brand or reference", true),
                select("format", "Contenance, format ou coffret", "Volume, format or gift set", true, listOf(
                    option("30ml", "30 ml"), option("50ml", "50 ml"), option("75ml", "75 ml"),
                    option("100ml", "100 ml"), option("coffret", "Coffret", "Gift set"),
                    option("testeur", "Testeur", "Tester"), option("autre", "Autre", "Other")
                )),
                select("family", "Famille olfactive / gamme", "Scent family / range", false, listOf(
                    option("floral", "Florale", "Floral"), option("boisee", "Boisée", "Woody"),
                    option("orientale", "Orientale", "Oriental"), option("fraiche", "Fraîche / agrumes", "Fresh / citrus"),
                    option("gourmande", "Gourmande", "Gourmand"), option("aquatique", "Aquatique", "Aquatic"),
                    option("autre", "Autre", "Other")
                )),
                text("batch", "Lot / référence fournisseur (si disponible)", "Batch / supplier reference (if available)"),
                area("special_order", "Commande spéciale ou réservation client", "Special order or customer reservation", false, 700)
            ),
            stages = listOf(
                stage("received", "Demande / réservation reçue", "Request / reservation received", "quote_pending", "cancelled"),
                stage("quote_pending", "Disponibilité / prix à confirmer", "Availability / price to confirm", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Confirmation client attendue", "Awaiting customer confirmation", "approved", "cancelled"),
                stage("approved", "Réservation confirmée", "Reservation confirmed", "waiting_parts", "in_progress"),
                stage("waiting_parts", "Réapprovisionnement attendu", "Waiting for replenishment", "in_progress"),
                stage("in_progress", "Réception et préparation de la commande", "Order received and prepared", "quality_check"),
                stage("quality_check", "Disponibilité vérifiée", "Availability checked", "ready"),
                stage("ready", "Disponible au retrait", "Ready for collection", "delivered"),
                stage("delivered", "Remis au client", "Handed to customer", "closed"),
                stage("closed", "Clôturée", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("services", "stock", "purchases", "suppliers", "customers", "cash", "loyalty", "reports"),
            notesFr = listOf("Le parcours principal reste catalogue produit, stock, approvisionnement et vente comptoir", "Ce dossier ne remplace ni une ligne de stock ni un encaissement confirmé")
        ),
        ActivityWorkflowDefinition(
            profile = "reparation",
            titleFr = "Réparation & dépannage", titleEn = "Repair & troubleshooting",
            purposeFr = "Prise en charge d'un équipement, diagnostic, devis, accord, pièces, intervention, test et restitution.",
            purposeEn = "Equipment intake, diagnosis, quote, approval, parts, repair, testing and return.",
            recordType = "repair_order", journey = "repair",
            fields = listOf(
                text("device", "Appareil, marque, modèle et numéro de série", "Device, make, model and serial number", true),
                area("fault", "Panne déclarée par le client", "Fault reported by customer", true, 1000),
                area("diagnosis", "Diagnostic / constat technique", "Technical diagnosis / findings", false, 1200),
                area("parts", "Pièces et composants nécessaires", "Required parts and components", false, 1000),
                area("warranty", "Garantie / conditions de restitution", "Warranty / return conditions", false, 700)
            ),
            stages = listOf(
                stage("received", "Appareil reçu", "Device received", "diagnostic", "cancelled"),
                stage("diagnostic", "Diagnostic", "Diagnosis", "quote_pending", "awaiting_approval", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "awaiting_approval", "approved", "cancelled"),
                stage("awaiting_approval", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Réparation autorisée", "Repair approved", "waiting_parts", "in_progress"),
                stage("waiting_parts", "Pièces attendues", "Waiting for parts", "in_progress"),
                stage("in_progress", "Réparation en cours", "Repair in progress", "quality_check"),
                stage("quality_check", "Tests et contrôle", "Tests and quality check", "in_progress", "ready"),
                stage("ready", "Prêt à restituer", "Ready for return", "delivered"),
                stage("delivered", "Restitué", "Returned", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "stock", "purchases", "cash", "team", "reports"),
            notesFr = listOf("État de l'appareil et accessoires déposés à consigner", "La garantie commerciale est définie par l'entreprise, pas par un défaut")
        ),
        ActivityWorkflowDefinition(
            profile = "menuiserie",
            titleFr = "Menuiserie & fabrication", titleEn = "Carpentry & manufacturing",
            purposeFr = "Ouvrage sur mesure, dimensions, plans, matières, fabrication, finition, installation et réception.",
            purposeEn = "Custom workpiece, dimensions, drawings, materials, manufacture, finishing, installation and acceptance.",
            recordType = "work_order", journey = "production",
            fields = listOf(
                text("piece", "Meuble, ouvrage ou chantier", "Furniture, workpiece or project", true),
                area("dimensions", "Dimensions, plan et spécifications", "Dimensions, plan and specifications", true, 1200),
                area("materials", "Bois, panneaux et quincaillerie", "Timber, panels and hardware", false, 700),
                area("finish", "Finition / couleur / traitement", "Finish / colour / treatment", false, 700),
                text("installation", "Lieu de pose / livraison", "Installation / delivery location", false, 700)
            ),
            stages = listOf(
                stage("received", "Demande reçue", "Request received", "diagnostic", "cancelled"),
                stage("diagnostic", "Étude technique / métrés", "Technical review / measurements", "quote_pending", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Ouvrage validé", "Work approved", "waiting_parts", "fabrication"),
                stage("waiting_parts", "Matières attendues", "Waiting for materials", "fabrication"),
                stage("fabrication", "Fabrication", "Manufacturing", "quality_check"),
                stage("quality_check", "Contrôle de finition", "Finishing quality check", "fabrication", "installation", "ready"),
                stage("installation", "Pose / installation", "Installation", "ready"),
                stage("ready", "Prêt", "Ready", "delivered"),
                stage("delivered", "Réception client", "Customer acceptance", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "stock", "purchases", "agenda", "team", "cash", "reports"),
            notesFr = listOf("Les dimensions et plans sont des données de commande versionnées", "Les besoins de pose se planifient avec les ressources et adresses du client")
        ),
        ActivityWorkflowDefinition(
            profile = "garage",
            titleFr = "Garage & mécanique automobile", titleEn = "Garage & automotive repair",
            purposeFr = "Entrée véhicule, kilométrage, panne, diagnostic, devis, pièces, main-d'œuvre, essai et remise.",
            purposeEn = "Vehicle intake, odometer, fault, diagnosis, quote, parts, labour, test drive and handover.",
            recordType = "repair_order", journey = "repair",
            fields = listOf(
                text("vehicle", "Véhicule, marque, modèle et immatriculation", "Vehicle, make, model and registration", true),
                number("odometer", "Kilométrage au dépôt", "Odometer at intake", min = 0, max = 5000000),
                area("fault", "Panne / intervention demandée", "Fault / requested work", true, 1000),
                area("diagnosis", "Diagnostic technique", "Technical diagnosis", false, 1200),
                area("parts", "Pièces, lubrifiants et consommables", "Parts, lubricants and consumables", false, 1000),
                area("handover", "Essai et contrôle de restitution", "Test drive and handover check", false, 800)
            ),
            stages = listOf(
                stage("received", "Véhicule reçu", "Vehicle received", "diagnostic", "cancelled"),
                stage("diagnostic", "Diagnostic mécanique", "Mechanical diagnosis", "quote_pending", "awaiting_approval", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "awaiting_approval", "approved", "cancelled"),
                stage("awaiting_approval", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Travaux autorisés", "Work approved", "waiting_parts", "in_progress"),
                stage("waiting_parts", "Pièces attendues", "Waiting for parts", "in_progress"),
                stage("in_progress", "Travaux en cours", "Work in progress", "quality_check"),
                stage("quality_check", "Essai et contrôle qualité", "Test and quality check", "in_progress", "ready"),
                stage("ready", "Prêt à restituer", "Ready for handover", "delivered"),
                stage("delivered", "Véhicule remis", "Vehicle handed over", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "stock", "purchases", "agenda", "team", "cash", "reports"),
            notesFr = listOf("Kilométrage et état au dépôt doivent être figés à la réception", "Pièces et main-d'œuvre ne sont jamais assimilées à un encaissement")
        ),
        ActivityWorkflowDefinition(
            profile = "nettoyage",
            titleFr = "Nettoyage & entretien de locaux", titleEn = "Cleaning & facility maintenance",
            purposeFr = "Contrat/site, zones, fréquence, checklist, équipe, matériel, intervention et contrôle qualité.",
            purposeEn = "Contract/site, zones, frequency, checklist, team, equipment, service delivery and quality control.",
            recordType = "service_order", journey = "service",
            fields = listOf(
                text("site", "Site client, adresse et zones", "Customer site, address and zones", true),
                area("tasks", "Tâches et niveau de service", "Tasks and service level", true, 1000),
                text("team", "Équipe prévue (affectation à confirmer)", "Planned team (assignment to confirm)"),
                area("equipment", "Produits et matériel", "Products and equipment", false, 800),
                area("checklist", "Checklist / critères de contrôle", "Checklist / acceptance criteria", false, 1200)
            ),
            stages = listOf(
                stage("received", "Demande reçue", "Request received", "quote_pending", "approved", "cancelled"),
                stage("quote_pending", "Devis / contrat à confirmer", "Quote / contract to confirm", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Contrat / intervention validé", "Contract / service approved", "planning"),
                stage("planning", "Intervention planifiée", "Service scheduled", "on_site", "cancelled"),
                stage("on_site", "Équipe sur site", "Team on site", "in_progress"),
                stage("in_progress", "Travaux en cours", "Work in progress", "quality_check"),
                stage("quality_check", "Contrôle / checklist", "Quality check / checklist", "in_progress", "ready"),
                stage("ready", "Intervention terminée", "Service completed", "delivered"),
                stage("delivered", "Service réceptionné", "Service accepted", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "agenda", "team", "stock", "purchases", "cash", "reports"),
            notesFr = listOf("Contrats récurrents, sites multiples et fréquences sont à paramétrer sans inventer de cadence", "Les contrôles qualité et preuves de passage doivent être horodatés")
        ),
        ActivityWorkflowDefinition(
            profile = "domicile",
            titleFr = "Services à domicile", titleEn = "Home services",
            purposeFr = "Demande d'intervention à une adresse, accès, créneau, technicien, matériel, exécution et acceptation.",
            purposeEn = "Home service request, access, time slot, technician, equipment, execution and customer acceptance.",
            recordType = "service_order", journey = "service",
            fields = listOf(
                text("address", "Adresse, quartier et repère d'intervention", "Service address, neighbourhood and directions", true),
                area("service", "Prestation demandée et consignes d'accès", "Requested service and access instructions", true, 1000),
                text("provider", "Intervenant souhaité (affectation à confirmer)", "Preferred provider (assignment to confirm)"),
                area("materials", "Matériel et consommables nécessaires", "Required equipment and consumables", false, 800),
                date("visit", "Date de visite souhaitée", "Preferred visit date")
            ),
            stages = listOf(
                stage("received", "Demande reçue", "Request received", "quote_pending", "approved", "cancelled"),
                stage("quote_pending", "Devis à confirmer", "Quote to confirm", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Intervention validée", "Service approved", "planning"),
                stage("planning", "Intervention planifiée", "Service scheduled", "on_site", "cancelled"),
                stage("on_site", "Intervenant arrivé", "Provider arrived", "in_progress"),
                stage("in_progress", "Intervention en cours", "Service in progress", "quality_check"),
                stage("quality_check", "Contrôle / validation client", "Quality check / customer validation", "in_progress", "ready"),
                stage("ready", "Terminé", "Completed", "delivered"),
                stage("delivered", "Réception client", "Customer acceptance", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "agenda", "team", "stock", "cash", "reports"),
            notesFr = listOf("Adresse et localisation sont soumises au consentement et au besoin de service", "Les frais de déplacement sont des lignes de devis, pas une hypothèse automatique")
        ),
        ActivityWorkflowDefinition(
            profile = "impression",
            titleFr = "Imprimerie & reprographie", titleEn = "Printing & reprographics",
            purposeFr = "Commande d'impression, support, format, quantité, épreuve, validation, production, finition et retrait.",
            purposeEn = "Print order, media, format, quantity, proof, approval, production, finishing and collection.",
            recordType = "work_order", journey = "production",
            fields = listOf(
                select("format", "Format, support et dimensions", "Format, media and dimensions", true, listOf(
                    option("A6", "A6"), option("A5", "A5"), option("A4", "A4"), option("A3", "A3"), option("A2", "A2"),
                    option("carte_visite", "Carte de visite", "Business card"), option("flyer", "Flyer"),
                    option("affiche", "Affiche", "Poster"), option("grand_format", "Grand format", "Large format"),
                    option("autre", "Autre", "Other")
                )),
                number("quantity", "Quantité commandée", "Quantity ordered", true, 1, 1000000),
                select("colors", "Couleurs et mode d'impression", "Colours and print process", false, listOf(
                    option("mono", "Noir et blanc", "Black and white"), option("cmyk", "Quadrichromie", "CMYK"),
                    option("spot", "Couleurs Pantone / directes", "Pantone / spot colours"), option("other", "Autre", "Other")
                )),
                area("proof", "Épreuve et validation client", "Proof and customer approval", false, 800),
                area("finishing", "Finition, façonnage et reliure", "Finishing, binding and assembly", false, 800)
            ),
            stages = listOf(
                stage("received", "Commande reçue", "Order received", "quote_pending", "proof_ready", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "waiting_customer", "proof_ready", "cancelled"),
                stage("waiting_customer", "Validation client attendue", "Awaiting customer approval", "approved", "cancelled"),
                stage("proof_ready", "Épreuve prête", "Proof ready", "approved", "production", "cancelled"),
                stage("approved", "Commande validée", "Order approved", "production"),
                stage("production", "Production", "Production", "quality_check"),
                stage("quality_check", "Contrôle qualité", "Quality check", "production", "ready"),
                stage("ready", "Prête au retrait", "Ready for collection", "delivered"),
                stage("delivered", "Remise client", "Handed to customer", "closed"),
                stage("closed", "Clôturée", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "stock", "purchases", "agenda", "cash", "team", "reports"),
            notesFr = listOf("Quantité, format et épreuve validée sont figés avant lancement de production", "Fichiers sources soumis à des droits d'accès et à une politique de conservation")
        ),
        ActivityWorkflowDefinition(
            profile = "photo_evenementiel",
            titleFr = "Photographie & événementiel", titleEn = "Photography & events",
            purposeFr = "Événement, lieu, date, forfait, liste de prises de vue, équipe, captation, post-production et livraison.",
            purposeEn = "Event, venue, date, package, shot list, crew, capture, post-production and delivery.",
            recordType = "work_order", journey = "production",
            fields = listOf(
                text("event", "Événement, organisateur et lieu", "Event, organiser and venue", true, 700),
                date("date", "Date de l'événement", "Event date", true),
                area("deliverables", "Forfait, livrables et quantités", "Package, deliverables and quantities", true, 1200),
                text("crew", "Équipe / prestataires souhaités", "Preferred crew / providers"),
                area("equipment", "Matériel et besoins logistiques", "Equipment and logistical needs", false, 900)
            ),
            stages = listOf(
                stage("received", "Demande reçue", "Request received", "quote_pending", "planning", "cancelled"),
                stage("quote_pending", "Devis à établir", "Quote to prepare", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Événement confirmé", "Event confirmed", "planning"),
                stage("planning", "Préparation", "Preparation", "shooting", "cancelled"),
                stage("shooting", "Captation", "Capture", "post_production"),
                stage("post_production", "Tri / post-production", "Selection / post-production", "quality_check"),
                stage("quality_check", "Contrôle des livrables", "Deliverables quality check", "post_production", "ready"),
                stage("ready", "Livrables prêts", "Deliverables ready", "delivered"),
                stage("delivered", "Livraison effectuée", "Delivered", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "agenda", "team", "stock", "cash", "reports"),
            notesFr = listOf("Droits à l'image, autorisations et durée de conservation restent à documenter avant production", "La livraison des fichiers n'est pas assimilée au transfert automatique de propriété intellectuelle")
        ),
        ActivityWorkflowDefinition(
            profile = "autre",
            titleFr = "Autre activité configurable", titleEn = "Other configurable activity",
            purposeFr = "Parcours paramétrable par l'organisation, sans imposer des étapes ou champs métier non validés.",
            purposeEn = "Configurable workflow without imposing unapproved business fields or stages.",
            recordType = "work_order", journey = "configurable",
            fields = listOf(
                text("service", "Prestation ou commande", "Service or order", true),
                area("specifications", "Description / spécifications", "Description / specifications", true, 1200),
                area("resources", "Ressources et consommables", "Resources and consumables", false, 800),
                area("instructions", "Consignes complémentaires", "Additional instructions", false, 800),
                date("delivery", "Échéance souhaitée", "Preferred due date")
            ),
            stages = listOf(
                stage("received", "Reçu", "Received", "quote_pending", "approved", "cancelled"),
                stage("quote_pending", "Devis à confirmer", "Quote to confirm", "waiting_customer", "approved", "cancelled"),
                stage("waiting_customer", "Accord client attendu", "Awaiting customer approval", "approved", "cancelled"),
                stage("approved", "Validé", "Approved", "in_progress"),
                stage("in_progress", "En cours", "In progress", "quality_check"),
                stage("quality_check", "Contrôle", "Quality check", "ready"),
                stage("ready", "Prêt", "Ready", "delivered"),
                stage("delivered", "Livré", "Delivered", "closed"),
                stage("closed", "Clôturé", "Closed"),
                stage("cancelled", "Annulée", "Cancelled")
            ),
            sharedModules = listOf("customers", "services", "agenda", "team", "stock", "cash", "reports"),
            notesFr = listOf("L'organisation doit configurer et valider ses propres champs et transitions avant usage réel")
        )
    )

    val profiles: List<String> = all.map { it.profile }
    private val byProfile = all.associateBy { it.profile }

    fun get(profile: String?): ActivityWorkflowDefinition =
        byProfile[profile] ?: byProfile.getValue("autre")

    fun nextStatusCodes(profile: String?, status: String): List<String> =
        get(profile).stage(if (status == "open") "received" else status)?.next.orEmpty()

    fun canTransition(profile: String?, from: String, to: String): Boolean =
        to in nextStatusCodes(profile, from)

    fun validate(profile: String?, values: Map<String, String>): List<String> {
        val errors = mutableListOf<String>()
        get(profile).fields.forEach { field ->
            val value = values[field.key].orEmpty().trim()
            if (field.required && value.isEmpty()) {
                errors += field.key
                return@forEach
            }
            if (value.isEmpty()) return@forEach
            if (value.length > field.maxLength) {
                errors += field.key
                return@forEach
            }
            when (field.kind) {
                ActivityFieldKind.NUMBER -> {
                    val parsed = value.toLongOrNull()
                    if (!value.matches(Regex("[0-9]{1,16}")) || parsed == null || parsed > 9007199254740991L || (field.min != null && parsed < field.min) ||
                        (field.max != null && parsed > field.max)
                    ) errors += field.key
                }
                ActivityFieldKind.DATE -> {
                    val valid = value.matches(Regex("[0-9]{4}-[0-9]{2}-[0-9]{2}")) && !value.startsWith("0000-") && runCatching { LocalDate.parse(value).toString() == value }.getOrDefault(false)
                    if (!valid) errors += field.key
                }
                ActivityFieldKind.SELECT -> if (field.options.none { it.value == value }) errors += field.key
                else -> Unit
            }
        }
        return errors
    }
}
