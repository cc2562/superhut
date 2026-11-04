package com.zhiquxy.rice

import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import com.umeng.commonsdk.UMConfigure

/**
 * 应用入口。
 *
 * 友盟的统计与性能 SDK 现在由 Flutter 官方组件（umeng_common_sdk / umeng_apm_sdk）自带，
 * 正式初始化在 Dart 侧拿到用户同意后触发。这里只做两件官方要求、且**不采集数据**的事：
 *
 * 1. `UMConfigure.preInit`：官方要求调用正式 init 之前必须先预加载；
 * 2. `UMCrash.initConfig`：崩溃 / ANR 等采集开关必须在 init 之前生效。
 *
 * 用户同意隐私政策后，Dart 侧会先调用 [grantConsent] 回执授权，再触发正式 init。
 */
class SuperhutApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        val logEnabled = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        UMConfigure.setLogEnabled(logEnabled)
        UMConfigure.preInit(this, UMENG_APP_KEY, UMENG_CHANNEL)
        UmengApm.configure()
    }

    companion object {
        /** 友盟后台「超级包菜」Android 应用的 AppKey。 */
        const val UMENG_APP_KEY = "6aeac349863270068cb58c1b"

        /** 分发渠道号（友盟后台渠道维度使用）。 */
        const val UMENG_CHANNEL = "official"

        @Volatile
        private var consentGranted = false

        /**
         * 回执隐私授权；只在用户同意「使用体验分析」之后由 Dart 层调用。
         *
         * 必须早于正式 init，否则 SDK 会打印「未调用隐私授权 API」的告警。
         *
         * @return 是否处于已回执状态
         */
        @JvmStatic
        fun grantConsent(context: Context): Boolean {
            if (consentGranted) return true
            synchronized(SuperhutApplication::class.java) {
                if (consentGranted) return true
                UMConfigure.submitPolicyGrantResult(context.applicationContext, true)
                consentGranted = true
            }
            return true
        }
    }
}
