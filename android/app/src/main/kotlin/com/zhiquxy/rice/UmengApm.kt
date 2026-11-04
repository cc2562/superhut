package com.zhiquxy.rice

import android.os.Bundle
import com.umeng.umcrash.UMCrash

/**
 * U-APM 性能监控配置。
 *
 * 必须在 `UMConfigure.init()` **之前**调用（把采集开关交给 SDK 初始化读取）；
 * 与统计一样，只在用户同意「使用体验分析」后才会被执行，
 * 未同意时连这一层配置都不会发生。
 */
internal object UmengApm {

    /** 全部采集能力都打开：崩溃、ANR、卡顿、启动耗时、内存、网络、页面、耗电。 */
    fun configure() {
        val bundle = Bundle().apply {
            putBoolean(UMCrash.KEY_ENABLE_CRASH_JAVA, true)
            putBoolean(UMCrash.KEY_ENABLE_CRASH_NATIVE, true)
            putBoolean(UMCrash.KEY_ENABLE_ANR, true)
            // PA：页面/卡顿监控，超时阈值 2s。
            putBoolean(UMCrash.KEY_ENABLE_PA, true)
            putLong(UMCrash.KEY_PA_TIMEOUT_TIME, 2000L)
            putBoolean(UMCrash.KEY_ENABLE_LAUNCH, true)
            putBoolean(UMCrash.KEY_ENABLE_MEM, true)
            putBoolean(UMCrash.KEY_ENABLE_NET, true)
            putBoolean(UMCrash.KEY_ENABLE_PAGE, true)
            putBoolean(UMCrash.KEY_ENABLE_POWER, true)
            putBoolean(UMCrash.KEY_ENABLE_MEMLEAK, true)
        }
        UMCrash.initConfig(bundle)
    }
}
