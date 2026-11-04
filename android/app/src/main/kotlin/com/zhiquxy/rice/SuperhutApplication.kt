package com.zhiquxy.rice

import android.app.Application
import android.content.Context
import android.content.pm.ApplicationInfo
import com.umeng.commonsdk.UMConfigure

/**
 * 应用入口。
 *
 * 友盟的统计与性能 SDK 由 Flutter 官方组件（umeng_common_sdk / umeng_apm_sdk）自带，
 * 正式初始化在 Dart 侧拿到用户同意后触发。
 *
 * 这里**不在 onCreate 调用 preInit**：友盟《合规配置指引》要求预初始化不得早于
 * 用户同意，因此 preInit 与采集开关一起收敛到 [grantConsent] 里，由 Dart 层在
 * 用户勾选「使用体验分析」后调用，随后紧接着做正式 init。
 */
class SuperhutApplication : Application() {

    override fun onCreate() {
        super.onCreate()
        // 只控制 SDK 日志输出，不触碰任何采集逻辑。
        val logEnabled = (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE) != 0
        UMConfigure.setLogEnabled(logEnabled)
    }

    companion object {
        /** 友盟后台「超级包菜」Android 应用的 AppKey。 */
        const val UMENG_APP_KEY = "6aeac349863270068cb58c1b"

        /** 分发渠道号（友盟后台渠道维度使用）。 */
        const val UMENG_CHANNEL = "official"

        @Volatile
        private var consentGranted = false

        /**
         * 回执隐私授权并完成预初始化；只在用户同意「使用体验分析」之后由 Dart 层调用。
         *
         * 顺序遵循友盟合规指引：用户同意 → preInit（不采集）→ 采集开关 → 正式 init
         * （正式 init 由 Flutter 官方组件在收到本方法返回值后发起）。
         *
         * @return 是否处于已回执状态
         */
        @JvmStatic
        fun grantConsent(context: Context): Boolean {
            if (consentGranted) return true
            synchronized(SuperhutApplication::class.java) {
                if (consentGranted) return true
                val appContext = context.applicationContext
                UMConfigure.preInit(appContext, UMENG_APP_KEY, UMENG_CHANNEL)
                // U-APM 的采集开关必须先于 UMConfigure.init 生效。
                UmengApm.configure()
                UMConfigure.submitPolicyGrantResult(appContext, true)
                consentGranted = true
            }
            return true
        }
    }
}
