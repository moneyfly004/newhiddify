package com.proxyapp.proxy_app

import android.os.Build
import androidx.annotation.RequiresApi
import libcore.ExchangeContext
import libcore.LocalDNSTransport
import java.net.InetAddress
import java.net.UnknownHostException

/**
 * 简化的 LocalDNSTransport 实现
 * 用于 libcore.aar 的 DNS 解析
 */
object SimpleLocalResolver : LocalDNSTransport {
    
    override fun raw(): Boolean {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q
    }
    
    override fun networkHandle(): Long {
        return 0
    }
    
    @RequiresApi(Build.VERSION_CODES.Q)
    override fun exchange(ctx: ExchangeContext, message: ByteArray) {
        // 简化实现：直接返回错误
        ctx.errnoCode(114514)
    }
    
    override fun lookup(ctx: ExchangeContext, network: String, domain: String) {
        // 使用线程池执行 DNS 查询
        Thread {
            try {
                val addresses = InetAddress.getAllByName(domain)
                if (addresses.isNotEmpty()) {
                    val result = addresses.mapNotNull { it.hostAddress }.joinToString("\n")
                    ctx.success(result)
                } else {
                    ctx.errnoCode(114514)
                }
            } catch (e: UnknownHostException) {
                ctx.errorCode(3) // NXDOMAIN
            } catch (e: Exception) {
                ctx.errnoCode(114514)
            }
        }.start()
    }
}

