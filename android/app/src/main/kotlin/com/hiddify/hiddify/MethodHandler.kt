package com.hiddify.hiddify

import android.util.Log
import com.hiddify.hiddify.bg.BoxService
import com.hiddify.hiddify.constant.Status
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.nekohasekai.libbox.Libbox
import io.nekohasekai.mobile.Mobile
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.GlobalScope
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch
import java.io.File

class MethodHandler(private val scope: CoroutineScope) : FlutterPlugin,
    MethodChannel.MethodCallHandler {
    private var channel: MethodChannel? = null

    companion object {
        const val TAG = "A/MethodHandler"
        const val channelName = "com.hiddify.app/method"

        enum class Trigger(val method: String) {
            Setup("setup"),
            ParseConfig("parse_config"),
            changeHiddifyOptions("change_hiddify_options"),
            GenerateConfig("generate_config"),
            Start("start"),
            Stop("stop"),
            Restart("restart"),
            SelectOutbound("select_outbound"),
            UrlTest("url_test"),
            ClearLogs("clear_logs"),
            GenerateWarpConfig("generate_warp_config"),
        }
    }

    override fun onAttachedToEngine(flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(
            flutterPluginBinding.binaryMessenger,
            channelName,
        )
        channel!!.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            Trigger.Setup.method -> {
                GlobalScope.launch {
                    result.runCatching {
                           val baseDir = Application.application.filesDir                
                            baseDir.mkdirs()
                            // 使用内部存储目录而不是外部存储，避免权限问题
                            // 优先使用 filesDir 下的 working 目录，确保有完整权限
                            val workingDir = Application.application.filesDir.resolve("working")
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
                            
                            Log.d(TAG, "base dir: ${baseDir.path}")
                            Log.d(TAG, "working dir: ${workingDir.path}")
                            Log.d(TAG, "temp dir: ${tempDir.path}")
                            
                            try {
                                Mobile.setup()
                                Libbox.redirectStderr(File(workingDir, "stderr2.log").path)
                            } catch (e: Exception) {
                                Log.e(TAG, "Failed to setup Mobile/Libbox: ${e.message}", e)
                                throw e
                            }

                            success("")
                    }
                }
            }

            Trigger.ParseConfig.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val path = args["path"] as String
                        val tempPath = args["tempPath"] as String
                        val debug = args["debug"] as Boolean
                        val msg = BoxService.parseConfig(path, tempPath, debug)
                        success(msg)
                    }
                }
            }

            Trigger.changeHiddifyOptions.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as String
                        Settings.configOptions = args
                        success(true)
                    }
                }
            }

            Trigger.GenerateConfig.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val path = args["path"] as String
                        val options = Settings.configOptions
                        if (options.isBlank() || path.isBlank()) {
                            error("blank properties")
                        }
                        val config = BoxService.buildConfig(path, options)
                        success(config)
                    }
                }
            }

            Trigger.Start.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val configPath = args["path"] as String? ?: ""
                        val profileName = args["name"] as String? ?: ""
                        
                        Log.d(TAG, "=== Start service called ===")
                        Log.d(TAG, "Config path: $configPath")
                        Log.d(TAG, "Profile name: $profileName")
                        
                        // 验证配置路径
                        if (configPath.isBlank()) {
                            Log.e(TAG, "❌ Config path is blank")
                            error("Configuration path is empty")
                            return@launch
                        }
                        
                        // 验证配置文件是否存在
                        val configFile = File(configPath)
                        if (!configFile.exists()) {
                            Log.e(TAG, "❌ Config file does not exist: $configPath")
                            Log.e(TAG, "Absolute path: ${configFile.absolutePath}")
                            error("Configuration file not found: $configPath")
                            return@launch
                        }
                        
                        if (!configFile.canRead()) {
                            Log.e(TAG, "❌ Config file is not readable: $configPath")
                            error("Configuration file is not readable: $configPath")
                            return@launch
                        }
                        
                        if (configFile.length() == 0L) {
                            Log.e(TAG, "❌ Config file is empty: $configPath")
                            error("Configuration file is empty: $configPath")
                            return@launch
                        }
                        
                        Log.d(TAG, "✅ Config file validation passed")
                        Log.d(TAG, "Config file size: ${configFile.length()} bytes")
                        
                        Settings.activeConfigPath = configPath
                        Settings.activeProfileName = profileName
                        
                        Log.d(TAG, "Settings updated: activeConfigPath=${Settings.activeConfigPath}, activeProfileName=${Settings.activeProfileName}")
                        
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (started) {
                            Log.w(TAG, "⚠️ Service is already running")
                            return@launch success(true)
                        }
                        
                        Log.d(TAG, "Calling mainActivity.startService()...")
                        mainActivity.startService()
                        Log.d(TAG, "✅ startService() called")
                        success(true)
                    }
                }
            }

            Trigger.Stop.method -> {
                scope.launch {
                    result.runCatching {
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) {
                            Log.w(TAG, "service is not running")
                            return@launch success(true)
                        }
                        BoxService.stop()
                        success(true)
                    }
                }
            }

            Trigger.Restart.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Settings.activeConfigPath = args["path"] as String? ?: ""
                        Settings.activeProfileName = args["name"] as String? ?: ""
                        val mainActivity = MainActivity.instance
                        val started = mainActivity.serviceStatus.value == Status.Started
                        if (!started) return@launch success(true)
                        val restart = Settings.rebuildServiceMode()
                        if (restart) {
                            mainActivity.reconnect()
                            BoxService.stop()
                            delay(1000L)
                            mainActivity.startService()
                            return@launch success(true)
                        }
                        runCatching {
                            Libbox.newStandaloneCommandClient().serviceReload()
                            success(true)
                        }.onFailure {
                            error(it)
                        }
                    }
                }
            }

            Trigger.SelectOutbound.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Libbox.newStandaloneCommandClient()
                            .selectOutbound(
                                args["groupTag"] as String,
                                args["outboundTag"] as String
                            )
                        success(true)
                    }
                }
            }

            Trigger.UrlTest.method -> {
                scope.launch {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        Libbox.newStandaloneCommandClient()
                            .urlTest(
                                args["groupTag"] as String
                            )
                        success(true)
                    }
                }
            }

            Trigger.ClearLogs.method -> {
                scope.launch {
                    result.runCatching {
                        MainActivity.instance.onServiceResetLogs(mutableListOf())
                        success(true)
                    }
                }
            }

            Trigger.GenerateWarpConfig.method -> {
                scope.launch(Dispatchers.IO) {
                    result.runCatching {
                        val args = call.arguments as Map<*, *>
                        val warpConfig = Mobile.generateWarpConfig(
                            args["license-key"] as String,
                            args["previous-account-id"] as String,
                            args["previous-access-token"] as String,
                        )
                        success(warpConfig)
                    }
                }
            }

            else -> result.notImplemented()
        }
    }
}