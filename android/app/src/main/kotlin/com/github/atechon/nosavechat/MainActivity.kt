package com.github.atechon.nosavechat

import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
  private val CHANNEL = "com.github.atechon.nosavechat/launch"

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
      when (call.method) {
        "isAppInstalled" -> {
          val packageName = call.argument<String>("package")
          if (packageName != null) {
            try {
              packageManager.getPackageInfo(packageName, 0)
              result.success(true)
            } catch (e: PackageManager.NameNotFoundException) {
              result.success(false)
            }
          } else {
            result.success(false)
          }
        }
        "launchApp" -> {
          val packageName = call.argument<String>("package")
          val phone = call.argument<String>("phone")
          val text = call.argument<String>("text") ?: ""
          if (packageName != null && phone != null) {
            try {
              val uriString = if (packageName.contains("whatsapp")) {
                "whatsapp://send?phone=$phone&text=$text"
              } else {
                "tg://resolve?phone=$phone"
              }
              val uri = Uri.parse(uriString)
              val intent = Intent(Intent.ACTION_VIEW, uri)
              intent.setPackage(packageName)
              intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK) // Better override defaults
              if (intent.resolveActivity(packageManager) != null) {
                startActivity(intent)
                result.success(true)
              } else {
                result.success(false)
              }
            } catch (e: Exception) {
              result.success(false)
            }
          } else {
            result.success(false)
          }
        }
        else -> result.notImplemented()
      }
    }
  }
}