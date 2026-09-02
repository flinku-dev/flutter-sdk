package dev.flinku.flinku_sdk

import android.content.Context
import com.android.installreferrer.api.InstallReferrerClient
import com.android.installreferrer.api.InstallReferrerStateListener
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.CountDownLatch
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference
import kotlin.concurrent.thread

/**
 * Play Install Referrer bridge for deferred deep linking.
 *
 * Mirrors flinku-android-sdk [Flinku.configure] Install Referrer logic:
 * connect, read the referrer string when the response is OK, keep it only when
 * it contains `flinku_click=`, otherwise treat as unused. Never throws to Dart.
 */
class FlinkuSdkPlugin : FlutterPlugin, MethodCallHandler {
  private lateinit var channel: MethodChannel
  private var applicationContext: Context? = null

  override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    applicationContext = binding.applicationContext
    channel = MethodChannel(binding.binaryMessenger, "flinku_sdk/install_referrer")
    channel.setMethodCallHandler(this)
  }

  override fun onMethodCall(call: MethodCall, result: Result) {
    if (call.method == "getInstallReferrer") {
      getInstallReferrer(result)
    } else {
      result.notImplemented()
    }
  }

  private fun getInstallReferrer(result: Result) {
    val context = applicationContext
    if (context == null) {
      result.success(null)
      return
    }

    // Install Referrer callbacks arrive off the main thread; await on a worker
    // so we never block the Flutter UI isolate's platform thread indefinitely.
    thread(name = "flinku-install-referrer") {
      try {
        val latch = CountDownLatch(1)
        val out = AtomicReference<String?>(null)
        val referrerClient = InstallReferrerClient.newBuilder(context).build()

        referrerClient.startConnection(
          object : InstallReferrerStateListener {
            override fun onInstallReferrerSetupFinished(responseCode: Int) {
              if (responseCode == InstallReferrerClient.InstallReferrerResponse.OK) {
                try {
                  val referrer = referrerClient.installReferrer.installReferrer
                  if (referrer.contains("flinku_click=")) {
                    out.set(referrer)
                  }
                } catch (_: Exception) {
                  // ignore — return null
                }
              }
              try {
                referrerClient.endConnection()
              } catch (_: Exception) {
                // ignore
              }
              latch.countDown()
            }

            override fun onInstallReferrerServiceDisconnected() {}
          },
        )

        val completed = latch.await(5, TimeUnit.SECONDS)
        if (!completed) {
          try {
            referrerClient.endConnection()
          } catch (_: Exception) {
            // ignore
          }
          result.success(null)
        } else {
          result.success(out.get())
        }
      } catch (_: Exception) {
        result.success(null)
      }
    }
  }

  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    channel.setMethodCallHandler(null)
    applicationContext = null
  }
}
