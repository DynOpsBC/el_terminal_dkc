package com.dynops.bcwms.pick.di

import com.dynops.bcwms.pick.DefaultPickRepository
import com.dynops.bcwms.pick.PickRepository
import com.dynops.bcwms.pick.PickViewModel

object PickModule {
  fun provideRepository(): PickRepository = DefaultPickRepository()
  fun provideViewModel(repository: PickRepository = provideRepository()): PickViewModel = PickViewModel(repository)
}
