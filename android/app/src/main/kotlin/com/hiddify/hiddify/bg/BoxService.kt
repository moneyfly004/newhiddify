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

    private fun startCommandServer() {
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
                    Thread.sleep(200)
                } catch (e: Exception) {
                    Log.w(TAG, "Failed to delete existing command.sock: ${e.message}", e)
                    // 如果删除失败，尝试重命名而不是直接启动
                    val backupFile = File(workingDir, "command.sock.old.${System.currentTimeMillis()}")
                    try {
                        val renamed = commandSockFile.renameTo(backupFile)
                        Log.d(TAG, "Renamed existing command.sock to backup: $renamed")
                        if (renamed) {
                            Thread.sleep(200)
                        } else {
                            Log.w(TAG, "Failed to rename command.sock, may cause binding issues")
                        }
                    } catch (e2: Exception) {
                        Log.e(TAG, "Failed to rename command.sock: ${e2.message}", e2)
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
            val commandServer = CommandServer(this, 300)
            commandServer.start()
            this.commandServer = commandServer
            Log.d(TAG, "CommandServer started successfully in: ${workingDir.absolutePath}")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to start CommandServer: ${e.message}", e)
            Log.e(TAG, "Working directory path: ${workingDir.absolutePath}")
            Log.e(TAG, "Working directory exists: ${workingDir.exists()}")
            Log.e(TAG, "Working directory canWrite: ${workingDir.canWrite()}")
            Log.e(TAG, "Working directory canRead: ${workingDir.canRead()}")
            Log.e(TAG, "System working dir: ${System.getProperty("user.dir")}")
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
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            activeProfileName = Settings.activeProfileName

            val configOptions = Settings.configOptions
            if (configOptions.isBlank()) {
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            val content = try {
                Mobile.buildConfig(selectedConfigPath, configOptions)
            } catch (e: Exception) {
                Log.w(TAG, e)
                stopAndAlert(Alert.EmptyConfiguration)
                return
            }

            if (Settings.debugMode) {
                File(workingDir, "current-config.json").writeText(content)
            }

            withContext(Dispatchers.Main) {
                notification.show(activeProfileName, R.string.status_starting)
                binder.broadcast {
                    it.onServiceResetLogs(listOf())
                }
            }

            DefaultNetworkMonitor.start()
            Libbox.registerLocalDNSTransport(LocalResolver)
            Libbox.setMemoryLimit(!Settings.disableMemoryLimit)

            val newService = try {
                Libbox.newService(content, platformInterface)
            } catch (e: Exception) {
                stopAndAlert(Alert.CreateService, e.message)
                return
            }

            if (delayStart) {
                delay(1000L)
            }

            newService.start()
            boxService = newService
            commandServer?.setService(boxService)
            status.postValue(Status.Started)

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
            Settings.startedByUser = true
            initialize()
            try {
                startCommandServer()
            } catch (e: Exception) {
                stopAndAlert(Alert.StartCommandServer, e.message)
                return@launch
            }
            startService()
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

}