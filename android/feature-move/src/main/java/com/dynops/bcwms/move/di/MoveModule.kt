package com.dynops.bcwms.move.di

import com.dynops.bcwms.move.DefaultMoveRepository
import com.dynops.bcwms.move.MoveRepository
import com.dynops.bcwms.move.MoveViewModel

object MoveModule {
  fun provideRepository(): MoveRepository = DefaultMoveRepository()
  fun provideViewModel(repository: MoveRepository = provideRepository()): MoveViewModel = MoveViewModel(repository)
}
