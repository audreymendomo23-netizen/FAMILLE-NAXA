package cm.naxa.naxaservices

import org.junit.Assert.*
import org.junit.Test
import java.io.ByteArrayInputStream

class PrivateProfilePhotoTest {
    private val endpoint="https://example.supabase.co/functions/v1/naxa-services-auth"
    private val org="20000000-0000-4000-8000-000000000001"
    private val member="60000000-0000-4000-8000-000000000001"
    @Test fun privatePathsAreScopedAndCanonical() {
        val paths=PrivateProfilePhotoApi.paths(endpoint,org,member)
        assertEquals("$org/$member/avatar.jpg",paths.objectPath)
        assertEquals("https://example.supabase.co/storage/v1/object/authenticated/ns-profile-photos/$org/$member/avatar.jpg",paths.read)
        assertEquals("https://example.supabase.co/storage/v1/object/ns-profile-photos/$org/$member/avatar.jpg",paths.write)
        assertEquals("https://example.supabase.co/storage/v1/object/ns-profile-photos",paths.remove)
    }
    @Test fun invalidPathAndInsecureEndpointAreRejected() {
        for (args in listOf(Triple(endpoint,org,"../avatar.jpg"),Triple("http://example.supabase.co/functions/v1/naxa-services-auth",org,member),Triple("https://example.supabase.co/functions/v1/naxa-auth",org,member))) {
            assertTrue(runCatching { PrivateProfilePhotoApi.paths(args.first,args.second,args.third) }.isFailure)
        }
    }
    @Test fun readsAreBounded() {
        val valid=ByteArray(PrivateProfilePhotoApi.MAX_BYTES)
        assertEquals(valid.size,PrivateProfilePhotoApi.boundedRead(ByteArrayInputStream(valid)).size)
        assertTrue(runCatching { PrivateProfilePhotoApi.boundedRead(ByteArrayInputStream(ByteArray(valid.size+1))) }.isFailure)
    }
}
