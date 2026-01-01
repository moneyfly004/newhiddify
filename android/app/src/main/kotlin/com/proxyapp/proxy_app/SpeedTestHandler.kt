package com.proxyapp.proxy_app

import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import libcore.BoxInstance
import libcore.Libcore
import kotlinx.coroutines.*
import kotlin.coroutines.resume
import kotlin.coroutines.suspendCoroutine

/**
 * 基于 Sing-box 核心的测速处理器
 * 参考 NekoBoxForAndroid 的 TestInstance 实现
 */
class SpeedTestHandler(private val context: android.content.Context) {
    
    companion object {
        private const val TAG = "SpeedTestHandler"
        private const val DEFAULT_TEST_URL = "https://www.google.com/generate_204"
        private const val DEFAULT_TIMEOUT = 5000 // 5秒
    }
    
    private val testScope = CoroutineScope(Dispatchers.IO + SupervisorJob())
    
    fun setupMethodChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.proxyapp/speed_test"
        )
        
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "testNode" -> {
                    val configJson = call.argument<String>("config")
                    val testUrl = call.argument<String>("testUrl") ?: DEFAULT_TEST_URL
                    val timeout = call.argument<Int>("timeout") ?: DEFAULT_TIMEOUT
                    
                    if (configJson == null) {
                        result.error("INVALID_ARGUMENT", "配置不能为空", null)
                        return@setMethodCallHandler
                    }
                    
                    testScope.launch {
                        try {
                            val latency = testNodeWithSingbox(configJson, testUrl, timeout)
                            result.success(latency)
                        } catch (e: Exception) {
                            Log.e(TAG, "测速失败", e)
                            result.error("TEST_FAILED", e.message, null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
    
    /**
     * 使用 Sing-box 核心测试节点
     * 参考 NekoBoxForAndroid 的 TestInstance.doTest()
     */
    private suspend fun testNodeWithSingbox(
        configJson: String,
        testUrl: String,
        timeout: Int
    ): Int = suspendCoroutine { continuation ->
        var testBoxInstance: BoxInstance? = null
        
        try {
            Log.d(TAG, "开始测速: $testUrl, 超时: ${timeout}ms")
            
            // 创建临时的 BoxInstance（用于测试，不启动 VPN）
            testBoxInstance = Libcore.newSingBoxInstance(configJson, SimpleLocalResolver)
            
            // 启动 BoxInstance（但不启动 VPN）
            testBoxInstance.start()
            
            // 等待一小段时间，确保 BoxInstance 完全启动
            Thread.sleep(500)
            
            // 使用 Libcore.urlTest 测试真实连接
            val latency = Libcore.urlTest(testBoxInstance, testUrl, timeout)
            
            Log.d(TAG, "测速完成: ${latency}ms")
            
            // 关闭测试实例
            testBoxInstance.close()
            testBoxInstance = null
            
            continuation.resume(latency)
            
        } catch (e: Exception) {
            Log.e(TAG, "测速异常", e)
            
            // 确保关闭测试实例
            try {
                testBoxInstance?.close()
            } catch (closeError: Exception) {
                Log.e(TAG, "关闭测试实例失败", closeError)
            }
            
            continuation.resume(-1) // 返回 -1 表示测速失败
        }
    }
    
    fun dispose() {
        testScope.cancel()
    }
}

