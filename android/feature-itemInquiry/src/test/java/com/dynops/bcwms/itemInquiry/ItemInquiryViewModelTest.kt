package com.dynops.bcwms.itemInquiry

import com.dynops.bcwms.core.network.BcApiClient
import com.dynops.bcwms.core.network.BcConnectionProfile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ItemInquiryViewModelTest {
  private val dispatcher = StandardTestDispatcher()

  @Before
  fun setUp() {
    Dispatchers.setMain(dispatcher)
  }

  @After
  fun tearDown() {
    Dispatchers.resetMain()
  }

  @Test
  fun loadItemEmitsItemState() = runTest {
    val client = BcApiClient(BcConnectionProfile("tenant", "env", "company"))
    val viewModel = ItemInquiryViewModel(ItemRepository(client))

    viewModel.handle(ItemInquiryIntent.Load("1000"))
    dispatcher.scheduler.advanceUntilIdle()

    assertTrue(viewModel.state.value is ItemInquiryState.ItemLoaded)
  }
}
