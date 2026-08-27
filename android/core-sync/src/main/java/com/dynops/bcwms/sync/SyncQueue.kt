package com.dynops.bcwms.sync

interface SyncQueue {
  suspend fun enqueue(op: Op)
  suspend fun peek(): List<Op>
  suspend fun dequeue(op: Op)
}

