package cm.naxa.naxaservices

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ActivityWorkflowCatalogTest {
    @Test
    fun exposesAllThirteenActivityProfilesExactlyOnce() {
        assertEquals(
            listOf(
                "pressing", "coiffure", "couture", "beaute", "parfumerie",
                "reparation", "menuiserie", "garage", "nettoyage", "domicile",
                "impression", "photo_evenementiel", "autre"
            ),
            ActivityWorkflows.profiles
        )
        assertEquals(13, ActivityWorkflows.all.size)
        assertEquals(13, ActivityWorkflows.profiles.toSet().size)
    }

    @Test
    fun everyProfileHasUniqueFieldsStagesAndAReachableTerminalState() {
        ActivityWorkflows.all.forEach { workflow ->
            val fieldKeys = workflow.fields.map { it.key }
            assertEquals("Duplicate field key in " + workflow.profile, fieldKeys.size, fieldKeys.toSet().size)

            val codes = workflow.stages.map { it.code }
            assertEquals("Duplicate stage code in " + workflow.profile, codes.size, codes.toSet().size)
            workflow.stages.forEach { stage ->
                assertEquals(
                    "Duplicate transition in " + workflow.profile + "/" + stage.code,
                    stage.next.size,
                    stage.next.toSet().size
                )
                stage.next.forEach { next ->
                    assertTrue(
                        "Dangling transition " + workflow.profile + ": " + stage.code + " -> " + next,
                        next in codes
                    )
                }
            }

            val reached = mutableSetOf("received")
            val queue = ArrayDeque<String>().apply { add("received") }
            while (queue.isNotEmpty()) {
                val current = queue.removeFirst()
                workflow.stage(current)?.next.orEmpty().forEach { next ->
                    if (reached.add(next)) queue.addLast(next)
                }
            }
            assertEquals("Unreachable stages in " + workflow.profile, codes.toSet(), reached)
            assertTrue(workflow.profile, reached.contains(workflow.terminalStatus()))
            assertTrue(
                "Completion stage should be terminal for " + workflow.profile,
                workflow.stage(workflow.terminalStatus())?.next.isNullOrEmpty()
            )
            if (workflow.profile != "pressing") {
                assertTrue("Cancellation stage missing for " + workflow.profile, reached.contains("cancelled"))
                assertTrue(
                    "Cancellation must be terminal for " + workflow.profile,
                    workflow.stage("cancelled")?.next.isNullOrEmpty()
                )
            }
            assertEquals(
                "Required field validation mismatch in " + workflow.profile,
                workflow.fields.filter { it.required }.map { it.key },
                ActivityWorkflows.validate(workflow.profile, emptyMap())
            )
        }
    }

    @Test
    fun profileSpecificRequiredFieldsAndTypedConstraintsAreEnforced() {
        assertEquals(
            listOf("fault"),
            ActivityWorkflows.validate("garage", mapOf("vehicle" to "Toyota Yaris"))
        )
        assertEquals(
            listOf("measurements"),
            ActivityWorkflows.validate("couture", mapOf("garment" to "Robe"))
        )
        assertTrue(
            ActivityWorkflows.validate(
                "coiffure",
                mapOf("style" to "tresses", "technique" to "Nattes"
                )
            ).isEmpty()
        )
        assertEquals(
            listOf("format"),
            ActivityWorkflows.validate("impression", mapOf("format" to "unknown", "quantity" to "100"))
        )
        assertEquals(
            listOf("quantity"),
            ActivityWorkflows.validate("impression", mapOf("format" to "A4", "quantity" to "0"))
        )
        assertEquals(
            listOf("odometer"),
            ActivityWorkflows.validate("garage", mapOf("vehicle" to "Toyota", "fault" to "Freinage", "odometer" to "5000001"))
        )
        assertEquals(
            listOf("date"),
            ActivityWorkflows.validate(
                "photo_evenementiel",
                mapOf("event" to "Cérémonie", "date" to "2026-02-31", "deliverables" to "Album photo")
            )
        )
        assertEquals(
            listOf("protocol"),
            ActivityWorkflows.validate(
                "beaute",
                mapOf("treatment" to "soin_visage", "protocol" to "x".repeat(1001))
            )
        )
        assertEquals(
            listOf("format"),
            ActivityWorkflows.validate("parfumerie", mapOf("product" to "Parfum", "format" to "2L"))
        )
    }

    @Test
    fun typedFieldDefinitionsExposeSelectNumberDateAndTextAreaControls() {
        assertEquals(ActivityFieldKind.SELECT, ActivityWorkflows.get("coiffure").fields.first { it.key == "style" }.kind)
        assertEquals(ActivityFieldKind.TEXTAREA, ActivityWorkflows.get("couture").fields.first { it.key == "measurements" }.kind)
        assertEquals(ActivityFieldKind.NUMBER, ActivityWorkflows.get("garage").fields.first { it.key == "odometer" }.kind)
        assertEquals(ActivityFieldKind.DATE, ActivityWorkflows.get("photo_evenementiel").fields.first { it.key == "date" }.kind)
        assertEquals(1L, ActivityWorkflows.get("impression").fields.first { it.key == "quantity" }.min)
    }

    @Test
    fun recordTypesKeepRepairServiceAndRetailJourneysDistinct() {
        assertEquals("pressing_order", ActivityWorkflows.get("pressing").recordType)
        assertEquals("service_order", ActivityWorkflows.get("coiffure").recordType)
        assertEquals("service_order", ActivityWorkflows.get("beaute").recordType)
        assertEquals("repair_order", ActivityWorkflows.get("reparation").recordType)
        assertEquals("repair_order", ActivityWorkflows.get("garage").recordType)
        assertEquals("retail", ActivityWorkflows.get("parfumerie").recordType)
        assertEquals("work_order", ActivityWorkflows.get("couture").recordType)
        assertEquals("work_order", ActivityWorkflows.get("impression").recordType)
    }

    @Test
    fun legacyOpenStatusUsesTheSameReceivedTransitions() {
        assertEquals(
            ActivityWorkflows.nextStatusCodes("garage", "received"),
            ActivityWorkflows.nextStatusCodes("garage", "open")
        )
        assertEquals(
            ActivityWorkflows.get("couture").nextStages("received").map { it.code },
            ActivityWorkflows.get("couture").nextStages("open").map { it.code }
        )
    }

    @Test
    fun unknownProfilesFallBackToConfigurableOtherActivity() {
        assertEquals("autre", ActivityWorkflows.get("not-a-sector").profile)
        assertEquals("autre", ActivityWorkflows.get(null).profile)
        assertFalse(ActivityWorkflows.canTransition("coiffure", "in_progress", "post_production"))
    }

    @Test
    fun pressingHasItsOwnNonCancellableDepositAndCollectionJourney() {
        assertEquals(listOf("in_progress"), ActivityWorkflows.nextStatusCodes("pressing", "received"))
        assertEquals(listOf("ready"), ActivityWorkflows.nextStatusCodes("pressing", "in_progress"))
        assertEquals(listOf("picked_up"), ActivityWorkflows.nextStatusCodes("pressing", "ready"))
        assertTrue(ActivityWorkflows.nextStatusCodes("pressing", "picked_up").isEmpty())
        assertEquals(null, ActivityWorkflows.get("pressing").stage("cancelled"))
    }

    @Test
    fun allSectorTransitionPairsAreExactAndUnknownStatesAreDenied() {
        ActivityWorkflows.all.forEach { workflow ->
            workflow.stages.forEach { from ->
                workflow.stages.forEach { to ->
                    assertEquals(workflow.profile + ":" + from.code + " -> " + to.code,
                        to.code in from.next, ActivityWorkflows.canTransition(workflow.profile, from.code, to.code))
                }
                assertFalse(ActivityWorkflows.canTransition(workflow.profile, from.code, "unknown_state"))
                assertFalse(ActivityWorkflows.canTransition(workflow.profile, "unknown_state", from.code))
            }
        }
    }
    @Test
    fun everySectorFieldHasPositiveAndNegativeBoundaryCoverage() {
        ActivityWorkflows.all.forEach { workflow ->
            val sample=workflow.fields.associate { f -> f.key to when(f.kind) {
                ActivityFieldKind.SELECT -> f.options.first().value
                ActivityFieldKind.DATE -> "2028-02-29"
                ActivityFieldKind.NUMBER -> (f.min ?: 0L).toString()
                else -> "Recette"
            } }
            assertTrue(workflow.profile, ActivityWorkflows.validate(workflow.profile,sample).isEmpty())
            workflow.fields.forEach { f ->
                fun invalid(value:String)=assertTrue(workflow.profile+"/"+f.key+"/"+value.take(40), f.key in ActivityWorkflows.validate(workflow.profile,sample + (f.key to value)))
                if(f.required) invalid("  ")
                when(f.kind){
                    ActivityFieldKind.SELECT -> { f.options.forEach { assertFalse(f.key in ActivityWorkflows.validate(workflow.profile,sample + (f.key to it.value))) };invalid("__unknown__") }
                    ActivityFieldKind.DATE -> listOf("2027-02-29","2026-13-01","not-a-date").forEach(::invalid)
                    ActivityFieldKind.NUMBER -> { listOf("1.5","1e2","0x10","NaN","9223372036854775808").forEach(::invalid);f.min?.let{invalid((it-1).toString())};f.max?.let{invalid((it+1).toString())} }
                    else -> invalid("x".repeat(f.maxLength+1))
                }
            }
        }
    }
}
