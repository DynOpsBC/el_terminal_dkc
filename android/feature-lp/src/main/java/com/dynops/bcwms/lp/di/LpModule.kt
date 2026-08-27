package com.dynops.bcwms.lp.di

import com.dynops.bcwms.core.network.BcApiClient
import com.dynops.bcwms.lp.LpRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
object LpModule {
  @Provides
  fun provideLpRepository(apiClient: BcApiClient): LpRepository = LpRepository(apiClient)
}
