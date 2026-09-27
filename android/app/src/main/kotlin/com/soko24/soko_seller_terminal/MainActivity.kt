package com.soko24.soko_seller_terminal

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        @Volatile private var identityChannel: MethodChannel? = null
        fun refreshAmaraIdentity(): Boolean {
            if (android.os.Looper.myLooper() == android.os.Looper.getMainLooper()) return false
            val latch = java.util.concurrent.CountDownLatch(1)
            val refreshed = java.util.concurrent.atomic.AtomicBoolean(false)
            android.os.Handler(android.os.Looper.getMainLooper()).post {
                val channel = identityChannel
                if (channel == null) latch.countDown()
                else channel.invokeMethod("refresh", null, object : MethodChannel.Result {
                    override fun success(result: Any?) { refreshed.set(result == true); latch.countDown() }
                    override fun error(code: String, message: String?, details: Any?) { latch.countDown() }
                    override fun notImplemented() { latch.countDown() }
                })
            }
            return latch.await(15, java.util.concurrent.TimeUnit.SECONDS) && refreshed.get()
        }
    }
    override fun cleanUpFlutterEngine(engine: FlutterEngine) {
        identityChannel = null
        super.cleanUpFlutterEngine(engine)
    }
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, "soko/amara_identity").also { identityChannel = it }.setMethodCallHandler { call, result ->
            if (call.method != "publish") { result.notImplemented(); return@setMethodCallHandler }
            val assertion = call.argument<String>("assertion").orEmpty()
            val generation = call.argument<Number>("generation")?.toLong() ?: 0L
            val prefs = getSharedPreferences("amara_identity", Context.MODE_PRIVATE)
            if (generation >= prefs.getLong("generation", 0)) {
                prefs.edit().putString("assertion", assertion).putLong("generation", generation).commit()
            }
            result.success(true)
        }
    }
}
