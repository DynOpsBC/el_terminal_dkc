package com.dynops.bcwms.assembly.di

import com.dynops.bcwms.assembly.AssemblyRepository
import com.dynops.bcwms.assembly.AssemblyViewModel
import com.dynops.bcwms.assembly.DefaultAssemblyRepository

object AssemblyModule {
  fun provideRepository(): AssemblyRepository = DefaultAssemblyRepository()
  fun provideViewModel(repository: AssemblyRepository = provideRepository()): AssemblyViewModel = AssemblyViewModel(repository)
}
