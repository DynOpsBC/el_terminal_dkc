package com.dynops.bcwms.consume.di

import com.dynops.bcwms.consume.ConsumeRepository
import com.dynops.bcwms.consume.ConsumeViewModel
import com.dynops.bcwms.consume.DefaultConsumeRepository

object ConsumeModule {
  fun provideRepository(): ConsumeRepository = DefaultConsumeRepository()
  fun provideViewModel(repository: ConsumeRepository = provideRepository()): ConsumeViewModel = ConsumeViewModel(repository)
}
