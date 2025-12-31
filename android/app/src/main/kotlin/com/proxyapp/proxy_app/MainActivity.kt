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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.proxyapp/kernel"
    private val APP_INFO_CHANNEL = "com.proxyapp/app_info"
    private val FOREGROUND_SERVICE_CHANNEL = "com.proxyapp/foreground_service"
    private var singboxProcess: Process? = null
    private var mihomoProcess: Process? = null
    private lateinit var permissionHandler: PermissionHandler
    private lateinit var appInfoHandler: AppInfoHandler

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // 初始化权限处理器
        permissionHandler = PermissionHandler(this)
        permissionHandler.setupMethodChannel(flutterEngine)
        
        // 初始化应用信息处理器
        appInfoHandler = AppInfoHandler(packageManager)
        
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
        
        // 写入配置文件
        val configFile = File(applicationContext.filesDir, "singbox.json")
        try {
            FileWriter(configFile).use { writer ->
                writer.write(config ?: "{}")
            }
        } catch (e: IOException) {
            Log.e("MainActivity", "写入 Sing-box 配置失败", e)
            throw e
        }
        
        // 启动 singbox 进程
        // 注意：实际使用时需要将 libsingbox.so 放在 jniLibs 目录下
        val libDir = applicationContext.applicationInfo.nativeLibraryDir
        val singboxLib = File(libDir, "libsingbox.so")
        
        if (!singboxLib.exists()) {
            Log.w("MainActivity", "Sing-box 库文件不存在: ${singboxLib.absolutePath}")
            // 这里可以返回错误或使用备用方案
            throw IOException("Sing-box 库文件不存在")
        }
        
        val command = listOf(
            singboxLib.absolutePath,
            "run",
            "-c",
            configFile.absolutePath
        )
        
        try {
            singboxProcess = ProcessBuilder(command)
                .redirectErrorStream(true)
                .start()
            Log.d("MainActivity", "Sing-box 进程已启动")
        } catch (e: IOException) {
            Log.e("MainActivity", "启动 Sing-box 进程失败", e)
            throw e
        }
    }
    
    private fun startMihomo(config: String?) {
        // 停止其他内核
        singboxProcess?.destroy()
        singboxProcess = null
        
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
        singboxProcess?.destroy()
        singboxProcess = null
        
        mihomoProcess?.destroy()
        mihomoProcess = null
        
        Log.d("MainActivity", "所有代理内核已停止")
    }
    
    private fun getKernelStatus(): Map<String, Any> {
        val isSingboxRunning = singboxProcess?.isAlive ?: false
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
            permissionHandler.onActivityResult(requestCode, resultCode)
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
}
