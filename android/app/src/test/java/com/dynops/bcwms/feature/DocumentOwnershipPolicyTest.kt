package com.dynops.bcwms.feature

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DocumentOwnershipPolicyTest {
    @Test
    fun `document mutation requires resolved matching owner`() {
        assertFalse(canMutateAssignedDocument("", "MERVE"))
        assertFalse(canMutateAssignedDocument("MERVE", ""))
        assertFalse(canMutateAssignedDocument("MERVE", "OTHER"))
        assertTrue(canMutateAssignedDocument(" MERVE ", "merve"))
    }
}
