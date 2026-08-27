package com.dynops.bcwms.scanner

import android.media.AudioAttributes
import android.media.SoundPool

class BeepProvider {
  private val soundPool = SoundPool.Builder()
    .setMaxStreams(2)
    .setAudioAttributes(
      AudioAttributes.Builder()
        .setUsage(AudioAttributes.USAGE_ASSISTANCE_SONIFICATION)
        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
        .build(),
    )
    .build()

  fun success() {
    tone(1.0f)
  }

  fun error() {
    tone(0.55f)
  }

  private fun tone(rate: Float) {
    soundPool.play(0, 1.0f, 1.0f, 1, 0, rate)
  }
}
