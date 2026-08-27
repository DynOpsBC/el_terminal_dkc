package com.dynops.bcwms.count.di

import com.dynops.bcwms.count.CountRepository
import com.dynops.bcwms.count.CountViewModel
import com.dynops.bcwms.count.DefaultCountRepository
import com.dynops.bcwms.usecase.count.CreateCountSheet
import com.dynops.bcwms.usecase.count.GetCountSheets
import com.dynops.bcwms.usecase.count.PostCountSheet
import com.dynops.bcwms.usecase.count.RecordCount
import com.dynops.bcwms.usecase.count.StartRecount

object CountModule {
  fun provideRepository(): CountRepository = DefaultCountRepository()
  fun provideCreateCountSheet(repository: CountRepository = provideRepository()) = CreateCountSheet(repository::createSheet)
  fun provideRecordCount(repository: CountRepository = provideRepository()) = RecordCount(repository::recordCount)
  fun provideStartRecount(repository: CountRepository = provideRepository()) = StartRecount(repository::startRecount)
  fun providePostCountSheet(repository: CountRepository = provideRepository()) = PostCountSheet(repository::postSheet)
  fun provideGetCountSheets(repository: CountRepository = provideRepository()) = GetCountSheets(repository::getSheets)
  fun provideViewModel(repository: CountRepository = provideRepository()): CountViewModel = CountViewModel(repository)
}
