package com.dynops.bcwms

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertSame
import org.junit.Test

class BcApiPaginationTest {
    @Test
    fun `odata next link is returned exactly for the following page`() {
        val url = "https://api.example.test/lines?%24skiptoken=abc"
        assertEquals(url, BcApi.odataNextLink("""{"value":[],"@odata.nextLink":"$url"}"""))
    }

    @Test
    fun `last page and malformed response have no next link`() {
        assertNull(BcApi.odataNextLink("""{"value":[]}"""))
        assertNull(BcApi.odataNextLink("not-json"))
    }

    @Test
    fun `connection probe accepts local user endpoint without depending on LP data`() {
        val localUsers = BcApi.ApiResult(true, 200, "{}")
        val licensePlates = BcApi.ApiResult(false, 500, "LP data error")

        assertSame(localUsers, BcApi.selectConnectionProbeResult(localUsers, licensePlates))
    }

    @Test
    fun `connection probe accepts legacy LP endpoint when local user endpoint is absent`() {
        val localUsers = BcApi.ApiResult(false, 404, "missing")
        val licensePlates = BcApi.ApiResult(true, 200, "{}")

        assertSame(licensePlates, BcApi.selectConnectionProbeResult(localUsers, licensePlates))
    }

    @Test
    fun `connection failure explains missing BC package`() {
        val result = BcApi.ApiResult(false, 404, "missing")

        assertEquals(
            "WMS BC paketi bu ortamda erişilebilir değil. Doğru ortama güncel paketi yükleyin.",
            BcApi.connectionFailureMessage(result),
        )
    }

    @Test
    fun `connection retries temporary route and server failures`() {
        listOf(-1, 404, 408, 425, 429, 500, 503).forEach { code ->
            assertEquals(true, BcApi.isRetryableConnectionFailure(BcApi.ApiResult(false, code, "")))
        }
    }

    @Test
    fun `connection does not retry authentication and permission failures`() {
        listOf(400, 401, 403, 405).forEach { code ->
            assertEquals(false, BcApi.isRetryableConnectionFailure(BcApi.ApiResult(false, code, "")))
        }
    }

    @Test
    fun `mutation validation errors are definite but transport failures are ambiguous`() {
        listOf(-1, 408, 425, 429, 500, 503).forEach { code ->
            assertEquals(true, BcApi.isAmbiguousMutationFailure(BcApi.ApiResult(false, code, "")))
        }
        listOf(400, 401, 403, 404, 405, 409, 422).forEach { code ->
            assertEquals(false, BcApi.isAmbiguousMutationFailure(BcApi.ApiResult(false, code, "")))
        }
    }
}
