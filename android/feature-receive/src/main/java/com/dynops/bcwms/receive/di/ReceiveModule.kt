package com.dynops.bcwms.receive.di

import com.dynops.bcwms.core.network.BcApiClient
import com.dynops.bcwms.receive.ReceiveRepository
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.components.SingletonComponent

@Module
@InstallIn(SingletonComponent::class)
object ReceiveModule {
  @Provides
  fun provideReceiveRepository(apiClient: BcApiClient): ReceiveRepository = ReceiveRepository(apiClient)
}
