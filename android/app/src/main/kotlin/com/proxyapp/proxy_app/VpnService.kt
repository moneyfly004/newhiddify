package com.proxyapp.proxy_app

import android.annotation.SuppressLint
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.VpnService as BaseVpnService
import android.os.Build
import android.os.IBinder
import android.os.ParcelFileDescriptor
import android.util.Log
import androidx.core.app.NotificationCompat
import java.net.InetAddress

/**
 * VPN Service 用于建立系统级 VPN 连接
 * 参考 NekoBoxForAndroid 的实现
 */
class VpnService : BaseVpnService() {
    
    companion object {
        private const val TAG = "VpnService"
        
        // VPN 网络地址配置（参考 NekoBox）
        const val PRIVATE_VLAN4_CLIENT = "172.19.0.1"
        const val PRIVATE_VLAN4_ROUTER = "172.19.0.2"
        const val FAKEDNS_VLAN4_CLIENT = "198.18.0.0"
        const val PRIVATE_VLAN6_CLIENT = "fdfe:dcba:9876::1"
        const val PRIVATE_VLAN6_ROUTER = "fdfe:dcba:9876::2"
        
        // 单例实例
        @Volatile
        private var instance: VpnService? = null
        
        fun getInstance(): VpnService? = instance
    }
    
    private var vpnInterface: ParcelFileDescriptor? = null
    private val mtu = 1500
    private val NOTIFICATION_ID = 2001
    private val CHANNEL_ID = "moneyfly_vpn_service"
    private val prefs: SharedPreferences by lazy {
        getSharedPreferences("app_settings", Context.MODE_PRIVATE)
    }
    
    override fun onCreate() {
        super.onCreate()
        instance = this
        createNotificationChannel()
        Log.d(TAG, "VpnService 已创建")
    }
    
    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        // 启动前台服务（必须在 onStartCommand 中调用，而不是 onCreate）
        startForeground(NOTIFICATION_ID, createNotification())
        Log.d(TAG, "VPN Service 已启动（前台服务）")
        // 确保 instance 被设置
        instance = this
        return START_STICKY
    }
    
    override fun onBind(intent: Intent?): IBinder? {
        return super.onBind(intent)
    }
    
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "MoneyFly VPN",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "MoneyFly VPN 服务运行通知"
                setShowBadge(false)
            }
            val notificationManager = getSystemService(NotificationManager::class.java)
            notificationManager.createNotificationChannel(channel)
        }
    }
    
    private fun createNotification(): Notification {
        val intent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("MoneyFly VPN")
            .setContentText("VPN 服务运行中")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        closeVpn()
        instance = null
        Log.d(TAG, "VpnService 已销毁")
    }
    
    /**
     * 启动 VPN 连接
     * 参考 NekoBoxForAndroid 的 startVpn 方法
     */
    @SuppressLint("WakelockTimeout")
    fun startVpn(tunOptionsJson: String, tunPlatformOptionsJson: String): Int {
        Log.d(TAG, "开始启动 VPN")
        Log.d(TAG, "TUN 选项: $tunOptionsJson")
        
        // 从 SharedPreferences 读取 bypassLan 设置（默认 true）
        val bypassLan = prefs.getBoolean("bypassLan", true)
        Log.d(TAG, "绕过局域网: $bypassLan")
        
        try {
            // 关闭旧的 VPN 接口
            closeVpn()
            
            // 创建 VPN Builder
            val builder = Builder()
                .setSession("MoneyFly")
                .setMtu(mtu)
            
            // 添加 IPv4 地址
            builder.addAddress(PRIVATE_VLAN4_CLIENT, 30)
            
            // 添加 DNS 服务器（使用 VPN 路由器地址，Sing-box 会处理 DNS）
            builder.addDnsServer(PRIVATE_VLAN4_ROUTER)
            
            // 路由配置（参考 NekoBoxForAndroid）
            // 由于 auto_route: false，需要手动添加路由
            if (bypassLan) {
                // 绕过局域网：添加私有网络路由
                // 10.0.0.0/8
                builder.addRoute("10.0.0.0", 8)
                // 172.16.0.0/12
                builder.addRoute("172.16.0.0", 12)
                // 192.168.0.0/16
                builder.addRoute("192.168.0.0", 16)
                // VPN 路由器地址
                builder.addRoute(PRIVATE_VLAN4_ROUTER, 32)
                // FakeDNS 地址
                builder.addRoute(FAKEDNS_VLAN4_CLIENT, 15)
                Log.d(TAG, "已添加绕过局域网路由")
            } else {
                // 全局路由：所有流量走 VPN
                builder.addRoute("0.0.0.0", 0)
                Log.d(TAG, "已添加全局路由")
            }
            
            // Android 10+ 设置计量网络
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                builder.setMetered(false)
            }
            
            // 建立 VPN 连接
            vpnInterface = builder.establish()
            
            if (vpnInterface == null) {
                Log.e(TAG, "VPN 接口创建失败")
                return -1
            }
            
            val fd = vpnInterface!!.fd
            Log.d(TAG, "VPN 接口已创建，文件描述符: $fd")
            
            return fd
            
        } catch (e: Exception) {
            Log.e(TAG, "启动 VPN 失败", e)
            closeVpn()
            return -1
        }
    }
    
    /**
     * 关闭 VPN 连接
     */
    fun closeVpn() {
        try {
            vpnInterface?.close()
            vpnInterface = null
            Log.d(TAG, "VPN 接口已关闭")
        } catch (e: Exception) {
            Log.e(TAG, "关闭 VPN 接口失败", e)
        }
    }
    
    /**
     * 保护 Socket（防止被 VPN 循环）
     */
    fun protectSocket(fd: Int): Boolean {
        return try {
            protect(fd)
            true
        } catch (e: Exception) {
            Log.e(TAG, "保护 Socket 失败: $fd", e)
            false
        }
    }
    
}

