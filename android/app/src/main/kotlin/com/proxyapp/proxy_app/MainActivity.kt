package com.proxyapp.proxy_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.util.Log
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileWriter
import java.io.IOException
import libcore.BoxInstance
import libcore.Libcore

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.proxyapp/kernel"
    private val APP_INFO_CHANNEL = "com.proxyapp/app_info"
    private val FOREGROUND_SERVICE_CHANNEL = "com.proxyapp/foreground_service"
    private var singboxInstance: BoxInstance? = null
    private var mihomoProcess: Process? = null
    private lateinit var permissionHandler: PermissionHandler
    private lateinit var appInfoHandler: AppInfoHandler
    private lateinit var speedTestHandler: SpeedTestHandler
    private var isLibcoreInitialized = false

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 初始化 libcore 日志系统
        initLibcore()
        
        // 初始化权限处理器
        permissionHandler = PermissionHandler(this)
        permissionHandler.setupMethodChannel(flutterEngine)
        
        // 初始化应用信息处理器
        appInfoHandler = AppInfoHandler(packageManager)
        
        // 初始化测速处理器
        speedTestHandler = SpeedTestHandler(applicationContext)
        speedTestHandler.setupMethodChannel(flutterEngine)
        
        // 设置应用信息 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, APP_INFO_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> {
                    appInfoHandler.getInstalledApps(result)
                }
                "getAppIcon" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        appInfoHandler.getAppIcon(packageName, result)
                    } else {
                        result.error("INVALID_ARGUMENT", "packageName 不能为空", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        // 设置前台服务 MethodChannel
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FOREGROUND_SERVICE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    val title = call.argument<String>("title") ?: "MoneyFly"
                    val content = call.argument<String>("content") ?: "正在运行"
                    try {
                        startForegroundService(title, content)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "启动前台服务失败", e)
                        result.error("START_SERVICE_FAILED", e.message, null)
                    }
                }
                "stopService" -> {
                    try {
                        stopForegroundService()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "停止前台服务失败", e)
                        result.error("STOP_SERVICE_FAILED", e.message, null)
                    }
                }
                "updateNotification" -> {
                    val title = call.argument<String>("title") ?: "MoneyFly"
                    val content = call.argument<String>("content") ?: "正在运行"
                    try {
                        updateNotification(title, content)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "更新通知失败", e)
                        result.error("UPDATE_NOTIFICATION_FAILED", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "start_singbox" -> {
                    val config = call.argument<String>("config")
                    try {
                        startSingbox(config)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "启动 Sing-box 失败", e)
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "start_mihomo" -> {
                    val config = call.argument<String>("config")
                    try {
                        startMihomo(config)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "启动 Mihomo 失败", e)
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stop_proxy" -> {
                    try {
                        stopAllKernels()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e("MainActivity", "停止代理失败", e)
                        result.error("STOP_FAILED", e.message, null)
                    }
                }
                "get_kernel_status" -> {
                    val status = getKernelStatus()
                    result.success(status)
                }
                else -> result.notImplemented()
            }
        }
    }
    
    private fun startSingbox(config: String?) {
        // 停止其他内核
        mihomoProcess?.destroy()
        mihomoProcess = null
        
        // 停止之前的实例（确保完全关闭）
        try {
            singboxInstance?.close()
        } catch (e: Exception) {
            Log.e("MainActivity", "关闭之前的 Sing-box 实例失败", e)
        }
        singboxInstance = null
        
        // 启动 VPN Service（必须在启动 Sing-box 之前）
        startVpnService()
        
        // 等待 VPN Service 完全启动（最多等待 2 秒）
        var waitCount = 0
        while (VpnService.getInstance() == null && waitCount < 20) {
            Thread.sleep(100)
            waitCount++
        }
        
        if (VpnService.getInstance() == null) {
            Log.e("MainActivity", "VPN Service 启动超时")
            throw IOException("VPN Service 启动超时")
        }
        
        Log.d("MainActivity", "VPN Service 已就绪")
        
        // 等待一小段时间，确保端口释放
        Thread.sleep(200)
        
        try {
            val configJson = config ?: "{}"
            Log.d("MainActivity", "使用 libcore.aar 启动 Sing-box")
            Log.d("MainActivity", "配置长度: ${configJson.length}")
            
            // 使用 libcore.aar 的 API 创建 BoxInstance
            singboxInstance = Libcore.newSingBoxInstance(configJson, SimpleLocalResolver)
            
            // 启动 BoxInstance
            singboxInstance?.start()
            
            Log.d("MainActivity", "Sing-box 已成功启动（使用 libcore.aar）")
        } catch (e: Exception) {
            Log.e("MainActivity", "启动 Sing-box 失败", e)
            singboxInstance?.close()
            singboxInstance = null
            stopVpnService()
            throw IOException("启动 Sing-box 失败: ${e.message}", e)
        }
    }
    
    /**
     * 启动 VPN Service
     */
    private fun startVpnService() {
        try {
            val intent = Intent(this, VpnService::class.java)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(intent)
            } else {
                startService(intent)
            }
            Log.d("MainActivity", "VPN Service 已启动")
        } catch (e: Exception) {
            Log.e("MainActivity", "启动 VPN Service 失败", e)
        }
    }
    
    /**
     * 停止 VPN Service
     */
    private fun stopVpnService() {
        try {
            val intent = Intent(this, VpnService::class.java)
            stopService(intent)
            Log.d("MainActivity", "VPN Service 已停止")
        } catch (e: Exception) {
            Log.e("MainActivity", "停止 VPN Service 失败", e)
        }
    }
    
    private fun startMihomo(config: String?) {
        // 停止其他内核
        try {
            singboxInstance?.close()
        } catch (e: Exception) {
            Log.e("MainActivity", "停止 Sing-box 失败", e)
        }
        singboxInstance = null
        
        // 写入配置文件
        val configFile = File(applicationContext.filesDir, "mihomo.yaml")
        try {
            FileWriter(configFile).use { writer ->
                writer.write(config ?: "")
            }
        } catch (e: IOException) {
            Log.e("MainActivity", "写入 Mihomo 配置失败", e)
            throw e
        }
        
        // 启动 mihomo 进程
        // 注意：实际使用时需要将 libmihomo.so 放在 jniLibs 目录下
        val libDir = applicationContext.applicationInfo.nativeLibraryDir
        val mihomoLib = File(libDir, "libmihomo.so")
        
        if (!mihomoLib.exists()) {
            Log.w("MainActivity", "Mihomo 库文件不存在: ${mihomoLib.absolutePath}")
            // 这里可以返回错误或使用备用方案
            throw IOException("Mihomo 库文件不存在")
        }
        
        val command = listOf(
            mihomoLib.absolutePath,
            "-f",
            configFile.absolutePath
        )
        
        try {
            mihomoProcess = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            Log.d("MainActivity", "Mihomo 进程已启动")
        } catch (e: IOException) {
            Log.e("MainActivity", "启动 Mihomo 进程失败", e)
            throw e
        }
    }
    
    private fun stopAllKernels() {
        // 先停止内核
        try {
            singboxInstance?.close()
        } catch (e: Exception) {
            Log.e("MainActivity", "停止 Sing-box 失败", e)
        }
        singboxInstance = null
        
        mihomoProcess?.destroy()
        mihomoProcess = null
        
        // 然后关闭 VPN Service（确保 VPN 接口被关闭）
        val vpnService = VpnService.getInstance()
        if (vpnService != null) {
            vpnService.closeVpn()
        }
        
        // 最后停止 VPN Service
        stopVpnService()
        
        Log.d("MainActivity", "所有代理内核已停止")
    }
    
    private fun getKernelStatus(): Map<String, Any> {
        // 简化状态检查：如果实例存在则认为正在运行
        val isSingboxRunning = singboxInstance != null
        val isMihomoRunning = mihomoProcess?.isAlive ?: false
        
        return mapOf(
            "singbox_running" to isSingboxRunning,
            "mihomo_running" to isMihomoRunning,
            "any_running" to (isSingboxRunning || isMihomoRunning)
        )
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (::permissionHandler.isInitialized) {
            val handled = permissionHandler.onActivityResult(requestCode, resultCode)
            if (!handled) {
                // 如果 PermissionHandler 没有处理，可能是其他请求
                Log.d("MainActivity", "onActivityResult: requestCode=$requestCode, resultCode=$resultCode")
            }
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        stopAllKernels()
        stopForegroundService()
    }
    
    private val NOTIFICATION_ID = 1001
    private val CHANNEL_ID = "moneyfly_foreground_service"
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MoneyFly 前台服务",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "MoneyFly 代理服务运行通知"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun startForegroundService(title: String, content: String) {
        createNotificationChannel()
        
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.d("MainActivity", "前台服务通知已显示: $title - $content")
    }
    
    private fun stopForegroundService() {
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.cancel(NOTIFICATION_ID)
        Log.d("MainActivity", "前台服务通知已取消")
    }
    
    private fun updateNotification(title: String, content: String) {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(content)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
        
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(NOTIFICATION_ID, notification)
        
        Log.d("MainActivity", "通知已更新: $title - $content")
    }
    
    /**
     * 初始化 libcore 日志系统
     * 必须在调用 newSingBoxInstance 之前调用
     */
    private fun initLibcore() {
        if (isLibcoreInitialized) {
            return
        }
        
        try {
            val process = applicationContext.packageName
            val cachePath = cacheDir.absolutePath + "/"
            val filesPath = filesDir.absolutePath + "/"
            val externalAssets = getExternalFilesDir(null)?.absolutePath ?: filesDir.absolutePath
            val externalAssetsPath = externalAssets + "/"
            
            val nativeInterface = MinimalNativeInterface(applicationContext)
            
            // 初始化 libcore（设置日志系统）
            Libcore.initCore(
                process,
                cachePath,
                filesPath,
                externalAssetsPath,
                1024, // maxLogSizeKb: 1MB
                true,  // logEnable: true
                nativeInterface,
                nativeInterface,
                SimpleLocalResolver
            )
            
            isLibcoreInitialized = true
            Log.d("MainActivity", "libcore 初始化成功")
        } catch (e: Exception) {
            Log.e("MainActivity", "初始化 libcore 失败", e)
            // 即使初始化失败，也继续尝试使用（可能会在 newSingBoxInstance 时失败）
        }
    }
}
