package com.proxyapp.proxy_app

import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.drawable.BitmapDrawable
import android.graphics.drawable.Drawable
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream

class AppInfoHandler(private val packageManager: PackageManager) {
    
    fun getInstalledApps(result: MethodChannel.Result) {
        try {
            val apps = packageManager.getInstalledPackages(PackageManager.GET_META_DATA)
            val appList = mutableListOf<Map<String, Any?>>()
            
            for (packageInfo in apps) {
                val appInfo = packageInfo.applicationInfo
                
                // 只包含用户应用，排除系统应用（可选）
                if (appInfo.flags and ApplicationInfo.FLAG_SYSTEM == 0 ||
                    appInfo.flags and ApplicationInfo.FLAG_UPDATED_SYSTEM_APP != 0) {
                    
                    val appName = packageManager.getApplicationLabel(appInfo).toString()
                    val packageName = packageInfo.packageName
                    
                    appList.add(mapOf(
                        "name" to appName,
                        "packageName" to packageName,
                        "iconPath" to null
                    ))
                }
            }
            
            result.success(appList)
        } catch (e: Exception) {
            result.error("GET_APPS_ERROR", "获取应用列表失败: ${e.message}", null)
        }
    }
    
    fun getAppIcon(packageName: String, result: MethodChannel.Result) {
        try {
            val appInfo = packageManager.getApplicationInfo(packageName, 0)
            val drawable = packageManager.getApplicationIcon(appInfo)
            
            val bitmap = drawableToBitmap(drawable)
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
            val byteArray = stream.toByteArray()
            
            result.success(byteArray)
        } catch (e: Exception) {
            result.error("GET_ICON_ERROR", "获取应用图标失败: ${e.message}", null)
        }
    }
    
    private fun drawableToBitmap(drawable: Drawable): Bitmap {
        if (drawable is BitmapDrawable && drawable.bitmap != null) {
            return drawable.bitmap
        }
        
        val bitmap = Bitmap.createBitmap(
            drawable.intrinsicWidth,
            drawable.intrinsicHeight,
            Bitmap.Config.ARGB_8888
        )
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, canvas.width, canvas.height)
        drawable.draw(canvas)
        return bitmap
    }
}

