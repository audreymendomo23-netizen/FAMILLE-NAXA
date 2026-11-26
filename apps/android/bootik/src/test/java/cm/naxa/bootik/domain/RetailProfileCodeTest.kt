package cm.naxa.bootik.domain

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class RetailProfileCodeTest {
    @Test
    fun retailerCatalogueHasExactlyFourteenUniqueStableCodes() {
        val codes = RetailProfileCode.entries.map { it.code }
        assertEquals(14, codes.size)
        assertEquals(14, codes.toSet().size)
    }

    @Test
    fun shoppingAndBrocanteHaveStableCodes() {
        assertEquals("shopping", RetailProfileCode.SHOPPING.code)
        assertEquals("brocante", RetailProfileCode.BROCANTE.code)
    }

    @Test
    fun informalPharmacyIsNotAnEnabledRetailProfile() {
        assertNull(RetailProfileCode.fromCode("pharmacie_informelle"))
    }

    @Test
    fun distributorCatalogueIsPreparedWithEightProfiles() {
        val codes = DistributorProfileCode.entries.map { it.code }
        assertEquals(8, codes.size)
        assertEquals(8, codes.toSet().size)
    }
}
