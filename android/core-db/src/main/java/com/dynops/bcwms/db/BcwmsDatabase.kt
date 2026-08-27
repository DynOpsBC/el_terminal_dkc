package com.dynops.bcwms.db

data class SyncOpEntity(
  val id: String,
  val type: String,
  val payloadJson: String,
  val createdAtEpochMillis: Long,
)

interface SyncQueueDao {
  suspend fun enqueue(op: SyncOpEntity)
  suspend fun pending(): List<SyncOpEntity>
}

class BcwmsDatabase
