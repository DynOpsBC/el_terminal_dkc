package com.dynops.bcwms.output.di

import com.dynops.bcwms.output.DefaultOutputRepository
import com.dynops.bcwms.output.OutputRepository
import com.dynops.bcwms.output.OutputViewModel

object OutputModule {
  fun provideRepository(): OutputRepository = DefaultOutputRepository()
  fun provideViewModel(repository: OutputRepository = provideRepository()): OutputViewModel = OutputViewModel(repository)
}
