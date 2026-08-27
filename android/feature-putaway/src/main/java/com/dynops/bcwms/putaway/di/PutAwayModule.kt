package com.dynops.bcwms.putaway.di

import com.dynops.bcwms.putaway.DefaultPutAwayRepository
import com.dynops.bcwms.putaway.PutAwayRepository
import com.dynops.bcwms.putaway.PutAwayViewModel

object PutAwayModule {
  fun provideRepository(): PutAwayRepository = DefaultPutAwayRepository()
  fun provideViewModel(repository: PutAwayRepository = provideRepository()): PutAwayViewModel = PutAwayViewModel(repository)
}
