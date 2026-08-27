package com.dynops.bcwms.sync

interface ConflictResolver {
  fun resolve(local: Op, remote: Op): Op
}

