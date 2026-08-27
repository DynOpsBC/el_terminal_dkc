package com.dynops.bcwms.macrobenchmark

import androidx.benchmark.macro.ExperimentalMetricApi
import androidx.benchmark.macro.FrameTimingMetric
import androidx.benchmark.macro.MacrobenchmarkRule
import androidx.benchmark.macro.PowerMetric
import androidx.benchmark.macro.junit4.MacrobenchmarkRule.Companion.DEFAULT_MEASURE_BLOCK_TIMEOUT_MS
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.uiautomator.By
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@OptIn(ExperimentalMetricApi::class)
@RunWith(AndroidJUnit4::class)
class ScanThroughputBenchmark {
  @get:Rule
  val benchmarkRule = MacrobenchmarkRule()

  @Test
  fun simulatedEightHourFifteenHundredScans() = benchmarkRule.measureRepeated(
    packageName = "com.dynops.bcwms",
    metrics = listOf(
      FrameTimingMetric(),
      PowerMetric(PowerMetric.Type.Battery())
    ),
    iterations = 1,
    setupBlock = {
      pressHome()
      startActivityAndWait()
    },
    measureBlock = {
      // Placeholder for RC lab run: drive 1500 hardware or intent scans across 8 hours.
      repeat(1500) { index ->
        device.findObject(By.res("com.dynops.bcwms", "scanInput"))?.text = "SIM-${index.toString().padStart(6, '0')}"
        device.findObject(By.res("com.dynops.bcwms", "confirmScan"))?.click()
      }
      device.waitForIdle(DEFAULT_MEASURE_BLOCK_TIMEOUT_MS)
    }
  )
}
