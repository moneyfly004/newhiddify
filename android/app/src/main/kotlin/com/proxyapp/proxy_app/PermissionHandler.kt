package com.proxyapp.proxy_app

import android.app.Activity
import android.content.Intent
import android.net.VpnService
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class PermissionHandler(private val activity: Activity) {
    private var vpnPermissionCallback: MethodChannel.Result? = null

    fun setupMethodChannel(flutterEngine: FlutterEngine) {
        val channel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "com.proxyapp/permissions"
        )

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "requestVpnPermission" -> {
                    vpnPermissionCallback = result
                    requestVpnPermission()
                }
                "checkVpnPermission" -> {
                    result.success(checkVpnPermission())
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun requestVpnPermission() {
        val intent = VpnService.prepare(activity)
        if (intent != null) {
            // 需要请求权限
            activity.startActivityForResult(intent, VPN_PERMISSION_REQUEST_CODE)
        } else {
            // 权限已授予
            vpnPermissionCallback?.success(true)
            vpnPermissionCallback = null
        }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int): Boolean {
        if (requestCode == VPN_PERMISSION_REQUEST_CODE) {
            val granted = resultCode == Activity.RESULT_OK
            vpnPermissionCallback?.success(granted)
            vpnPermissionCallback = null
            return true
        }
        return false
    }

    private fun checkVpnPermission(): Boolean {
        val intent = VpnService.prepare(activity)
        return intent == null
    }

    companion object {
        private const val VPN_PERMISSION_REQUEST_CODE = 1001
    }
}

