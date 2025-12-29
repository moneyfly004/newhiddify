package com.hiddify.hiddify.bg

import android.app.Service
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.os.PowerManager
import android.util.Log
import androidx.annotation.RequiresApi
import androidx.core.content.ContextCompat
import androidx.lifecycle.MutableLiveData
import com.hiddify.hiddify.Application
import com.hiddify.hiddify.R
import com.hiddify.hiddify.Settings
import com.hiddify.hiddify.constant.Action
import com.hiddify.hiddify.constant.Alert
import com.hiddify.hiddify.constant.Status
import go.Seq
import io.nekohasekai.libbox.BoxService
import io.nekohasekai.libbox.CommandServer
import io.nekohasekai.libbox.CommandServerHandler
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.libbox.PlatformInterface
import io.nekohasekai.libbox.SystemProxyStatus
import io.nekohasekai.mobile.Mobile
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withContext
import java.io.File

class BoxService(
        private val service: Service,
        private val platformInterface: PlatformInterface
) : CommandServerHandler {

    companion object {
        private const val TAG = "A/BoxService"

        private var initializeOnce = false
        private lateinit var workingDir: File
        private fun initialize() {
            if (initializeOnce) return
            val baseDir = Application.application.filesDir
            
            baseDir.mkdirs()
            // 使用内部存储目录而不是外部存储，避免权限问题
            // 优先使用 filesDir 下的 working 目录，确保有完整权限
            workingDir = Application.application.filesDir.resolve("working")
            workingDir.mkdirs()
            val tempDir = Application.application.cacheDir
            tempDir.mkdirs()
            
            // 确保目录有正确的权限
            workingDir.setWritable(true, false)
            workingDir.setReadable(true, false)
            workingDir.setExecutable(true, false)
            
            // 清理可能存在的旧 socket 文件
            val commandSockFile = File(workingDir, "command.sock")
            if (commandSockFile.exists()) {
                try {
                    commandSockFile.delete()
                    Log.d(TAG, "Deleted existing command.sock file")
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete existing command.sock: ${e.message}", e)
                }
            }
            
            Log.d(TAG, "base dir: ${baseDir.absolutePath}")
            Log.d(TAG, "working dir: ${workingDir.absolutePath}")
            Log.d(TAG, "temp dir: ${tempDir.absolutePath}")
            
            try {
                // 先设置当前工作目录，确保 CommandServer 使用正确的路径
                System.setProperty("user.dir", workingDir.absolutePath)
                
                // 调用 Libbox.setup() 设置目录路径，确保 CommandServer 知道正确的 working 目录
                // 这必须在 Mobile.setup() 之前调用，因为 CommandServer 依赖于这些路径
                try {
                    Libbox.setup(baseDir.path, workingDir.path, tempDir.path, false)
                    Log.d(TAG, "Libbox.setup() completed successfully")
                } catch (e: Exception) {
                    // 如果 Libbox.setup() 不存在或失败，记录警告但继续
                    Log.w(TAG, "Libbox.setup() failed or not available: ${e.message}", e)
                }
                
                Mobile.setup()
                Libbox.redirectStderr(File(workingDir, "stderr.log").path)
                
                Log.d(TAG, "Mobile.setup() completed successfully")
                Log.d(TAG, "Current working directory: ${System.getProperty("user.dir")}")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to setup Mobile/Libbox: ${e.message}", e)
                e.printStackTrace()
                throw e
            }
            initializeOnce = true
            return
        }

        fun parseConfig(path: String, tempPath: String, debug: Boolean): String {
            return try {
                Mobile.parse(path, tempPath, debug)
                ""
            } catch (e: Exception) {
                Log.w(TAG, e)
                e.message ?: "invalid config"
            }
        }

        fun buildConfig(path: String, options: String): String {
            return Mobile.buildConfig(path, options)
        }

        fun start() {
            val intent = runBlocking {
                withContext(Dispatchers.IO) {
                    Intent(Application.application, Settings.serviceClass())
                }
            }
            ContextCompat.startForegroundService(Application.application, intent)
        }

        fun stop() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_CLOSE).setPackage(
                            Application.application.packageName
                    )
            )
        }

        fun reload() {
            Application.application.sendBroadcast(
                    Intent(Action.SERVICE_RELOAD).setPackage(
                            Application.application.packageName
                    )
            )
        }
    }

    var fileDescriptor: ParcelFileDescriptor? = null

    private val status = MutableLiveData(Status.Stopped)
    private val binder = ServiceBinder(status)
    private val notification = ServiceNotification(status, service)
    private var boxService: BoxService? = null
    private var commandServer: CommandServer? = null
    private var receiverRegistered = false
    private val receiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            when (intent.action) {
                Action.SERVICE_CLOSE -> {
                    stopService()
                }

                Action.SERVICE_RELOAD -> {
                    serviceReload()
                }

                PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        serviceUpdateIdleMode()
                    }
                }
            }
        }
    }

    private suspend fun startCommandServer() {
        try {
            // 确保工作目录存在且有权限
            if (!workingDir.exists()) {
                val created = workingDir.mkdirs()
                Log.d(TAG, "Created working directory: $created, path: ${workingDir.absolutePath}")
            }
            
            // 检查并设置目录权限
            val writable = workingDir.setWritable(true, false)
            val readable = workingDir.setReadable(true, false)
            val executable = workingDir.setExecutable(true, false)
            Log.d(TAG, "Directory permissions - writable: $writable, readable: $readable, executable: $executable")
            Log.d(TAG, "Working directory absolute path: ${workingDir.absolutePath}")
            Log.d(TAG, "Working directory exists: ${workingDir.exists()}, canWrite: ${workingDir.canWrite()}, canRead: ${workingDir.canRead()}")
            
            // 验证目录权限
            if (!workingDir.canWrite()) {
                throw IllegalStateException("Working directory is not writable: ${workingDir.absolutePath}")
            }
            
            // 设置当前工作目录（虽然 Go 代码可能不读取，但为了保险起见）
            val originalDir = System.getProperty("user.dir")
            System.setProperty("user.dir", workingDir.absolutePath)
            Log.d(TAG, "Changed working directory from: $originalDir to: ${workingDir.absolutePath}")
            
            // 确保 Libbox 知道正确的 working 目录（如果 setup 方法可用）
            // 这很重要，因为 CommandServer 是 Go 代码，它依赖于 Libbox 的全局设置
            try {
                val baseDir = Application.application.filesDir
                val tempDir = Application.application.cacheDir
                Libbox.setup(baseDir.path, workingDir.path, tempDir.path, false)
                Log.d(TAG, "Libbox.setup() called before CommandServer start")
            } catch (e: Exception) {
                // 如果 Libbox.setup() 不存在或失败，记录警告但继续
                // 这可能意味着该版本的 Libbox 不需要显式 setup，或者使用其他方式
                Log.w(TAG, "Libbox.setup() not available or failed before CommandServer start: ${e.message}")
            }
            
            // 清理可能存在的旧 socket 文件（防止并发启动和权限问题）
            val commandSockFile = File(workingDir, "command.sock")
            if (commandSockFile.exists()) {
                Log.d(TAG, "Found existing command.sock file, attempting to delete...")
                try {
                    val deleted = commandSockFile.delete()
                    Log.d(TAG, "Deleted existing command.sock file: $deleted")
                    if (!deleted) {
                        Log.w(TAG, "Failed to delete command.sock, file may be in use")
                    }
                    // 等待一下确保文件系统同步
                    delay(200)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete existing command.sock: ${e.message}", e)
                    // 如果删除失败，尝试重命名而不是直接启动
                    val backupFile = File(workingDir, "command.sock.old.${System.currentTimeMillis()}")
                    try {
                        val renamed = commandSockFile.renameTo(backupFile)
                        Log.d(TAG, "Renamed existing command.sock to backup: $renamed")
                        if (renamed) {
                            delay(200)
                        } else {
                            Log.w(TAG, "Failed to rename command.sock, may cause binding issues")
                        }
                    } catch (e2: Exception) {
                        logToBoth("E", TAG, "Failed to rename command.sock: ${e2.message}")
                        Log.e(TAG, "Failed to rename command.sock", e2)
                        // 如果重命名也失败，仍然尝试启动，让 CommandServer 处理错误
                    }
                }
            } else {
                Log.d(TAG, "No existing command.sock file found")
            }
            
            Log.d(TAG, "Starting CommandServer in directory: ${workingDir.absolutePath}")
            Log.d(TAG, "Current system working dir: ${System.getProperty("user.dir")}")
            
            // 创建并启动 CommandServer
            // CommandServer 是 Go 代码，它会使用 Libbox 设置的 working 目录来创建 socket
            Log.d(TAG, "Creating CommandServer instance...")
            val commandServer = CommandServer(this, 300)
            Log.d(TAG, "CommandServer instance created, calling start()...")
            
            try {
                commandServer.start()
                Log.d(TAG, "CommandServer.start() completed without exception")
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ CommandServer.start() threw exception: ${e.message}")
                Log.e(TAG, "CommandServer.start() threw exception", e)
                e.printStackTrace()
                throw e
            }
            
            this.commandServer = commandServer
            Log.d(TAG, "CommandServer instance assigned, waiting for socket to be ready...")
            
            // 等待 CommandServer 完全启动并创建 socket 文件
            // 最多等待 3 秒，每 100ms 检查一次
            val maxWaitTime = 3000L // 3 秒
            val checkInterval = 100L // 100ms
            var waited = 0L
            var socketReady = false
            
            while (waited < maxWaitTime && !socketReady) {
                delay(checkInterval)
                waited += checkInterval
                
                // 检查 socket 文件是否存在
                if (commandSockFile.exists()) {
                    // 额外等待一下，确保 socket 完全准备好
                    delay(100)
                    socketReady = true
                    Log.d(TAG, "CommandServer socket file found after ${waited}ms")
                } else {
                    Log.d(TAG, "Waiting for CommandServer socket file... (${waited}ms)")
                }
            }
            
            if (!socketReady) {
                logToBoth("W", TAG, "⚠️ CommandServer socket file not found after ${maxWaitTime}ms")
                Log.w(TAG, "Socket file path: ${commandSockFile.absolutePath}")
                Log.w(TAG, "Working directory contents:")
                try {
                    workingDir.listFiles()?.forEach { file ->
                        Log.w(TAG, "  - ${file.name} (${file.length()} bytes, exists: ${file.exists()})")
                    }
                } catch (e: Exception) {
                    logToBoth("E", TAG, "Failed to list working directory: ${e.message}")
                    Log.e(TAG, "Failed to list working directory", e)
                }
                logToBoth("W", TAG, "Continuing anyway, CommandServer may use different connection method")
            } else {
                logToBoth("I", TAG, "✅ CommandServer started successfully and socket is ready")
                Log.d(TAG, "Socket file: ${commandSockFile.absolutePath}")
                Log.d(TAG, "Socket file size: ${commandSockFile.length()} bytes")
                Log.d(TAG, "Socket file readable: ${commandSockFile.canRead()}")
                Log.d(TAG, "Socket file writable: ${commandSockFile.canWrite()}")
            }
        } catch (e: Exception) {
            logToBoth("E", TAG, "❌ Failed to start CommandServer: ${e.message}")
            logToBoth("E", TAG, "Working directory path: ${workingDir.absolutePath}")
            logToBoth("E", TAG, "Working directory exists: ${workingDir.exists()}")
            logToBoth("E", TAG, "Working directory canWrite: ${workingDir.canWrite()}")
            logToBoth("E", TAG, "Working directory canRead: ${workingDir.canRead()}")
            logToBoth("E", TAG, "System working dir: ${System.getProperty("user.dir")}")
            Log.e(TAG, "Failed to start CommandServer", e)
            e.printStackTrace()
            throw e
        }
    }

    private var activeProfileName = ""
    private suspend fun startService(delayStart: Boolean = false) {
        try {
            Log.d(TAG, "starting service")
            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
            }

            val selectedConfigPath = Settings.activeConfigPath
            if (selectedConfigPath.isBlank()) {
                logToBoth("E", TAG, "❌ activeConfigPath is blank")
                stopAndAlert(Alert.EmptyConfiguration, "Configuration path is empty")
                return
            }
            logToBoth("I", TAG, "Active config path: $selectedConfigPath")
            
            // 验证配置文件是否存在
            val configFile = File(selectedConfigPath)
            Log.d(TAG, "Checking config file: ${configFile.absolutePath}")
            Log.d(TAG, "Config file exists: ${configFile.exists()}")
            
            if (!configFile.exists()) {
                logToBoth("E", TAG, "❌ Config file does not exist: $selectedConfigPath")
                Log.e(TAG, "Absolute path: ${configFile.absolutePath}")
                Log.e(TAG, "Parent directory exists: ${configFile.parentFile?.exists()}")
                Log.e(TAG, "Parent directory: ${configFile.parentFile?.absolutePath}")
                stopAndAlert(Alert.EmptyConfiguration, "Configuration file not found: $selectedConfigPath")
                return
            }
            
            // 检查文件是否可读
            if (!configFile.canRead()) {
                logToBoth("E", TAG, "❌ Config file is not readable: $selectedConfigPath")
                stopAndAlert(Alert.EmptyConfiguration, "Configuration file is not readable: $selectedConfigPath")
                return
            }
            
            val fileSize = configFile.length()
            logToBoth("I", TAG, "✅ Config file exists: ${configFile.absolutePath}, size: $fileSize bytes")
            
            if (fileSize == 0L) {
                logToBoth("E", TAG, "❌ Config file is empty: $selectedConfigPath")
                stopAndAlert(Alert.EmptyConfiguration, "Configuration file is empty: $selectedConfigPath")
                return
            }
            
            // 尝试读取文件内容的前几个字节，验证文件是否损坏
            try {
                val previewBytes = ByteArray(minOf(100, fileSize.toInt()))
                configFile.inputStream().use { it.read(previewBytes) }
                val preview = String(previewBytes).trim()
                Log.d(TAG, "Config file preview (first 100 chars): ${preview.take(100)}")
                if (!preview.startsWith("{") && !preview.startsWith("[")) {
                    logToBoth("W", TAG, "⚠️ Config file may not be valid JSON (doesn't start with { or [)")
                }
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to read config file preview: ${e.message}")
                Log.e(TAG, "Failed to read config file preview", e)
                // 不阻止启动，只是警告
                logToBoth("W", TAG, "Continuing despite preview read failure")
            }

            activeProfileName = Settings.activeProfileName
            Log.d(TAG, "Active profile name: $activeProfileName")

            val configOptions = Settings.configOptions
            if (configOptions.isBlank()) {
                logToBoth("E", TAG, "❌ configOptions is blank")
                stopAndAlert(Alert.EmptyConfiguration, "Configuration options are empty")
                return
            }
            logToBoth("I", TAG, "Config options length: ${configOptions.length}")
            
            // 验证 configOptions 是否是有效的 JSON
            try {
                org.json.JSONObject(configOptions)
                logToBoth("I", TAG, "✅ Config options is valid JSON")
            } catch (e: Exception) {
                logToBoth("W", TAG, "⚠️ Config options may not be valid JSON: ${e.message}")
                // 不阻止启动，因为可能是其他格式
            }

            val content = try {
                logToBoth("I", TAG, "Building config from path: $selectedConfigPath")
                Log.d(TAG, "Config options preview: ${configOptions.take(200)}...")
                
                val builtConfig = Mobile.buildConfig(selectedConfigPath, configOptions)
                logToBoth("I", TAG, "✅ Config built successfully, length: ${builtConfig.length}")
                
                if (builtConfig.isBlank()) {
                    logToBoth("E", TAG, "❌ Built config is empty")
                    throw IllegalStateException("Built config is empty")
                }
                
                // 验证构建的配置是否是有效的 JSON
                try {
                    org.json.JSONObject(builtConfig)
                    logToBoth("I", TAG, "✅ Built config is valid JSON")
                } catch (e: Exception) {
                    logToBoth("W", TAG, "⚠️ Built config may not be valid JSON: ${e.message}")
                    // 仍然继续，因为可能是其他格式或部分有效
                }
                
                // 检查配置中是否包含必要的字段
                if (!builtConfig.contains("\"outbounds\"") && !builtConfig.contains("\"outbound\"")) {
                    logToBoth("W", TAG, "⚠️ Built config may not contain outbounds")
                }
                
                // 过滤掉无效的 outbound（127.0.0.1 或 localhost）
                val filteredConfig = try {
                    val jsonObj = org.json.JSONObject(builtConfig)
                    if (jsonObj.has("outbounds")) {
                        val outbounds = jsonObj.getJSONArray("outbounds")
                        val validOutbounds = org.json.JSONArray()
                        var filteredCount = 0
                        
                        logToBoth("I", TAG, "开始过滤 outbounds，原始数量: ${outbounds.length()}")
                        
                        for (i in 0 until outbounds.length()) {
                            val outbound = outbounds.getJSONObject(i)
                            val server = outbound.optString("server", "")
                            val port = outbound.optInt("port", -1)
                            val tag = outbound.optString("tag", "unknown")
                            val type = outbound.optString("type", "unknown")
                            
                            // 过滤掉 127.0.0.1 或 localhost 的节点
                            if (server == "127.0.0.1" || server == "localhost" || 
                                server == "::1" || server.isEmpty()) {
                                filteredCount++
                                logToBoth("W", TAG, "⚠️ 过滤无效节点: tag=$tag, type=$type, server=$server, port=$port")
                                continue
                            }
                            
                            validOutbounds.put(outbound)
                        }
                        
                        if (filteredCount > 0) {
                            logToBoth("I", TAG, "✅ 已过滤 $filteredCount 个无效节点，剩余 ${validOutbounds.length()} 个有效节点")
                            jsonObj.put("outbounds", validOutbounds)
                            
                            // 如果过滤后没有有效节点，抛出异常阻止启动
                            if (validOutbounds.length() == 0) {
                                logToBoth("E", TAG, "❌ 过滤后没有有效的 outbound 节点！")
                                logToBoth("E", TAG, "订阅配置中只包含无效节点（127.0.0.1），无法连接")
                                logToBoth("E", TAG, "请检查订阅是否包含有效的代理服务器节点")
                                throw IllegalStateException("过滤后没有有效的 outbound 节点，订阅配置无效")
                            }
                            
                            jsonObj.toString()
                        } else {
                            builtConfig
                        }
                    } else {
                        builtConfig
                    }
                } catch (e: Exception) {
                    logToBoth("W", TAG, "无法解析配置 JSON 以过滤 outbounds: ${e.message}")
                    builtConfig
                }
                
                filteredConfig
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to build config: ${e.message}")
                logToBoth("E", TAG, "Exception type: ${e.javaClass.name}")
                logToBoth("E", TAG, "Config path: $selectedConfigPath")
                logToBoth("E", TAG, "Config options length: ${configOptions.length}")
                Log.e(TAG, "Failed to build config", e)
                Log.e(TAG, "Exception type: ${e.javaClass.name}")
                Log.e(TAG, "Config path: $selectedConfigPath")
                Log.e(TAG, "Config options length: ${configOptions.length}")
                e.printStackTrace()
                stopAndAlert(Alert.EmptyConfiguration, "Failed to build config: ${e.message}")
                return
            }

            if (Settings.debugMode) {
                File(workingDir, "current-config.json").writeText(content)
            }
            
            // 记录最终配置的 outbound 信息（用于调试）
            try {
                val jsonObj = org.json.JSONObject(content)
                if (jsonObj.has("outbounds")) {
                    val outbounds = jsonObj.getJSONArray("outbounds")
                    logToBoth("I", TAG, "✅ 最终配置包含 ${outbounds.length()} 个 outbound")
                    if (outbounds.length() > 0 && outbounds.length() <= 10) {
                        for (i in 0 until outbounds.length()) {
                            val outbound = outbounds.getJSONObject(i)
                            val tag = outbound.optString("tag", "unknown")
                            val type = outbound.optString("type", "unknown")
                            val server = outbound.optString("server", "unknown")
                            val port = outbound.optInt("port", -1)
                            logToBoth("I", TAG, "  Outbound[$i]: $tag ($type) -> $server:$port")
                        }
                    }
                }
            } catch (e: Exception) {
                // 忽略解析错误
            }

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            Log.d(TAG, "Starting network monitor and DNS transport")
            DefaultNetworkMonitor.start()
            Libbox.registerLocalDNSTransport(LocalResolver)
            Libbox.setMemoryLimit(!Settings.disableMemoryLimit)
            Log.d(TAG, "Network monitor and DNS transport started")

            // 确保 CommandServer 已经启动并准备好
            if (commandServer == null) {
                logToBoth("E", TAG, "❌ CommandServer is null, cannot start service")
                stopAndAlert(Alert.StartCommandServer, "CommandServer is not initialized")
                return
            }
            Log.d(TAG, "CommandServer is ready, creating BoxService")

            val newService = try {
                Log.d(TAG, "Creating new BoxService with config length: ${content.length}")
                val service = Libbox.newService(content, platformInterface)
                Log.d(TAG, "BoxService created successfully")
                service
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to create BoxService: ${e.message}")
                Log.e(TAG, "Failed to create BoxService", e)
                e.printStackTrace()
                stopAndAlert(Alert.CreateService, "Failed to create service: ${e.message}")
                return
            }

            if (delayStart) {
                Log.d(TAG, "Delaying service start by 1 second")
                delay(1000L)
            }

            Log.d(TAG, "Starting BoxService...")
            try {
                // 在启动服务之前，再次确认 CommandServer 状态
                if (commandServer == null) {
                    Log.e(TAG, "❌ CommandServer is null before starting BoxService!")
                    stopAndAlert(Alert.StartCommandServer, "CommandServer is null")
                    return
                }
                Log.d(TAG, "✅ CommandServer exists before starting BoxService")
                
                // 检查 socket 文件是否存在
                val commandSockFile = File(workingDir, "command.sock")
                Log.d(TAG, "CommandServer socket file exists: ${commandSockFile.exists()}, path: ${commandSockFile.absolutePath}")
                if (commandSockFile.exists()) {
                    Log.d(TAG, "Socket file size: ${commandSockFile.length()} bytes")
                }
                
                Log.d(TAG, "Calling newService.start()...")
                newService.start()
                Log.d(TAG, "✅ BoxService.start() completed successfully")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Failed to start BoxService: ${e.message}", e)
                Log.e(TAG, "Exception type: ${e.javaClass.name}")
                Log.e(TAG, "Exception cause: ${e.cause?.message}")
                e.printStackTrace()
                stopAndAlert(Alert.StartService, "Failed to start service: ${e.message}")
                return
            }
            
            boxService = newService
            Log.d(TAG, "BoxService instance assigned")
            
            // 确保 CommandServer 已经设置好服务引用
            try {
                commandServer?.setService(boxService)
                Log.d(TAG, "✅ CommandServer service reference set successfully")
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to set CommandServer service reference: ${e.message}")
                Log.e(TAG, "Failed to set CommandServer service reference", e)
                // 即使设置失败，也继续，因为服务已经启动
            }
            
            status.postValue(Status.Started)
            Log.d(TAG, "✅ Service status set to Started")

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_started)
            }
            notification.start()
        } catch (e: Exception) {
            stopAndAlert(Alert.StartService, e.message)
            return
        }
    }

    override fun serviceReload() {
        notification.close()
        status.postValue(Status.Starting)
        val pfd = fileDescriptor
        if (pfd != null) {
            pfd.close()
            fileDescriptor = null
        }
        commandServer?.setService(null)
        boxService?.apply {
            runCatching {
                close()
            }.onFailure {
                writeLog("service: error when closing: $it")
            }
            Seq.destroyRef(refnum)
        }
        boxService = null
        runBlocking {
            startService(true)
        }
    }

    override fun getSystemProxyStatus(): SystemProxyStatus {
        val status = SystemProxyStatus()
        if (service is VPNService) {
            status.available = service.systemProxyAvailable
            status.enabled = service.systemProxyEnabled
        }
        return status
    }

    override fun setSystemProxyEnabled(isEnabled: Boolean) {
        serviceReload()
    }

    @RequiresApi(Build.VERSION_CODES.M)
    private fun serviceUpdateIdleMode() {
        if (Application.powerManager.isDeviceIdleMode) {
            boxService?.pause()
        } else {
            boxService?.wake()
        }
    }

    private fun stopService() {
        if (status.value != Status.Started) return
        status.value = Status.Stopping
        if (receiverRegistered) {
            service.unregisterReceiver(receiver)
            receiverRegistered = false
        }
        notification.close()
        GlobalScope.launch(Dispatchers.IO) {
            val pfd = fileDescriptor
            if (pfd != null) {
                pfd.close()
                fileDescriptor = null
            }
            commandServer?.setService(null)
            boxService?.apply {
                runCatching {
                    close()
                }.onFailure {
                    writeLog("service: error when closing: $it")
                }
                Seq.destroyRef(refnum)
            }
            boxService = null
            Libbox.registerLocalDNSTransport(null)
            DefaultNetworkMonitor.stop()

            commandServer?.apply {
                close()
                Seq.destroyRef(refnum)
            }
            commandServer = null
            Settings.startedByUser = false
            withContext(Dispatchers.Main) {
                status.value = Status.Stopped
                service.stopSelf()
            }
        }
    }
    override fun postServiceClose() {
        // Not used on Android
    }

    private suspend fun stopAndAlert(type: Alert, message: String? = null) {
        Settings.startedByUser = false
        withContext(Dispatchers.Main) {
            if (receiverRegistered) {
                service.unregisterReceiver(receiver)
                receiverRegistered = false
            }
            notification.close()
            binder.broadcast { callback ->
                callback.onServiceAlert(type.ordinal, message)
            }
            status.value = Status.Stopped
        }
    }

    fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (status.value != Status.Stopped) return Service.START_NOT_STICKY
        status.value = Status.Starting

        if (!receiverRegistered) {
            ContextCompat.registerReceiver(service, receiver, IntentFilter().apply {
                addAction(Action.SERVICE_CLOSE)
                addAction(Action.SERVICE_RELOAD)
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    addAction(PowerManager.ACTION_DEVICE_IDLE_MODE_CHANGED)
                }
            }, ContextCompat.RECEIVER_NOT_EXPORTED)
            receiverRegistered = true
        }

        GlobalScope.launch(Dispatchers.IO) {
            logToBoth("I", TAG, "=== onStartCommand: Starting service initialization ===")
            Settings.startedByUser = true
            logToBoth("I", TAG, "Settings.startedByUser set to true")
            
            try {
                logToBoth("I", TAG, "Calling initialize()...")
                initialize()
                logToBoth("I", TAG, "✅ Initialization completed successfully")
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to initialize: ${e.message}")
                logToBoth("E", TAG, "Exception type: ${e.javaClass.name}")
                if (e.cause != null) {
                    logToBoth("E", TAG, "Exception cause: ${e.cause?.message}")
                }
                Log.e(TAG, "Failed to initialize", e)
                e.printStackTrace()
                stopAndAlert(Alert.StartCommandServer, "Initialization failed: ${e.message}")
                return@launch
            }
            
            try {
                logToBoth("I", TAG, "Calling startCommandServer()...")
                startCommandServer()
                logToBoth("I", TAG, "✅ CommandServer startup completed")
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ Failed to start CommandServer: ${e.message}")
                logToBoth("E", TAG, "Exception type: ${e.javaClass.name}")
                if (e.cause != null) {
                    logToBoth("E", TAG, "Exception cause: ${e.cause?.message}")
                }
                Log.e(TAG, "Failed to start CommandServer", e)
                Log.e(TAG, "Exception type: ${e.javaClass.name}")
                e.printStackTrace()
                stopAndAlert(Alert.StartCommandServer, e.message)
                return@launch
            }
            
            // 确保 CommandServer 完全准备好后再启动服务
            logToBoth("I", TAG, "Waiting 300ms for CommandServer to be fully ready...")
            delay(300) // 额外等待 300ms 确保 CommandServer 完全就绪
            logToBoth("I", TAG, "✅ Wait completed, starting BoxService...")
            
            try {
                startService()
                logToBoth("I", TAG, "✅ startService() completed")
            } catch (e: Exception) {
                logToBoth("E", TAG, "❌ startService() failed: ${e.message}")
                logToBoth("E", TAG, "Exception type: ${e.javaClass.name}")
                if (e.cause != null) {
                    logToBoth("E", TAG, "Exception cause: ${e.cause?.message}")
                }
                Log.e(TAG, "startService() failed", e)
                e.printStackTrace()
            }
            
            logToBoth("I", TAG, "=== onStartCommand: Service initialization completed ===")
        }
        return Service.START_NOT_STICKY
    }

    fun onBind(intent: Intent): IBinder {
        return binder
    }

    fun onDestroy() {
        binder.close()
    }

    fun onRevoke() {
        stopService()
    }

    fun writeLog(message: String) {
        binder.broadcast {
            it.onServiceWriteLog(message)
        }
    }
    
    // 同时写入 logcat 和应用日志的辅助方法
    private fun logToBoth(level: String, tag: String, message: String) {
        // 写入 logcat
        when (level) {
            "D" -> Log.d(tag, message)
            "I" -> Log.i(tag, message)
            "W" -> Log.w(tag, message)
            "E" -> Log.e(tag, message)
            else -> Log.d(tag, message)
        }
        // 写入应用日志界面
        // 所有错误和警告都写入，重要信息也写入
        val shouldWriteToApp = when {
            level == "E" -> true  // 所有错误都写入
            level == "W" -> true   // 所有警告都写入
            message.contains("❌") -> true  // 包含错误标记的
            message.contains("⚠️") -> true  // 包含警告标记的
            message.contains("✅") -> true   // 包含成功标记的重要信息
            message.contains("===") -> true  // 重要分隔标记
            message.contains("Failed") -> true  // 包含失败关键词
            message.contains("Error") -> true    // 包含错误关键词
            message.contains("Exception") -> true  // 包含异常关键词
            else -> false
        }
        if (shouldWriteToApp) {
            writeLog("[$level] $message")
        }
    }

}