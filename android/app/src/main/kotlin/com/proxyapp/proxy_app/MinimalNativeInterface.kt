package com.proxyapp.proxy_app

import android.content.Context
import android.net.ConnectivityManager
import android.net.wifi.WifiManager
import android.os.Build
import android.util.Log
import androidx.annotation.RequiresApi
import libcore.BoxPlatformInterface
import libcore.NB4AInterface
import java.net.InetSocketAddress

/**
 * NativeInterface 实现
 * 用于初始化 libcore 日志系统和 VPN 连接
 */
class MinimalNativeInterface(private val context: Context) : BoxPlatformInterface, NB4AInterface {
    
    companion object {
        private const val TAG = "MinimalNativeInterface"
    }
    
    // BoxPlatformInterface 实现
    override fun autoDetectInterfaceControl(fd: Int) {
        // 保护 Socket，防止被 VPN 循环
        val vpnService = VpnService.getInstance()
        if (vpnService != null) {
            vpnService.protectSocket(fd)
            Log.d(TAG, "保护 Socket: $fd")
        }
    }
    
    override fun openTun(singTunOptionsJson: String, tunPlatformOptionsJson: String): Long {
        Log.d(TAG, "openTun 被调用")
        Log.d(TAG, "TUN 选项: $singTunOptionsJson")
        
        val vpnService = VpnService.getInstance()
        if (vpnService == null) {
            Log.e(TAG, "VPN Service 未初始化")
            return -1
        }
        
        try {
            val fd = vpnService.startVpn(singTunOptionsJson, tunPlatformOptionsJson)
            if (fd > 0) {
                Log.d(TAG, "TUN 接口已创建，文件描述符: $fd")
                return fd.toLong()
            } else {
                Log.e(TAG, "TUN 接口创建失败")
                return -1
            }
        } catch (e: Exception) {
            Log.e(TAG, "创建 TUN 接口时出错", e)
            return -1
        }
    }
    
    override fun useProcFS(): Boolean {
        return Build.VERSION.SDK_INT < Build.VERSION_CODES.Q
    }
    
    @RequiresApi(Build.VERSION_CODES.Q)
    override fun findConnectionOwner(
        ipProto: Int, srcIp: String, srcPort: Int, destIp: String, destPort: Int
    ): Int {
        // 最小实现：返回 -1（未找到）
        return -1
    }
    
    override fun packageNameByUid(uid: Int): String {
        // 最小实现：返回 "android"
        return "android"
    }
    
    override fun uidByPackageName(packageName: String): Int {
        // 最小实现：返回 0
        return 0
    }
    
    override fun wifiState(): String {
        try {
            val wifiManager = context.getSystemService(Context.WIFI_SERVICE) as? WifiManager
            val connectionInfo = wifiManager?.connectionInfo
            return "${connectionInfo?.ssid ?: ""},${connectionInfo?.bssid ?: ""}"
        } catch (e: Exception) {
            return ","
        }
    }
    
    // NB4AInterface 实现
    override fun useOfficialAssets(): Boolean {
        return true
    }
    
    override fun selector_OnProxySelected(selectorTag: String, tag: String) {
        // 最小实现：不做任何操作
    }
}

