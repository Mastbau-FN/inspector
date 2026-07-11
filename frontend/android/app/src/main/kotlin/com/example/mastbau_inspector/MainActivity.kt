package com.mbgsolutions.inspector

import android.content.ActivityNotFoundException
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import android.view.KeyEvent
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val EVENT_CHANNEL = "volume_button_events"
    private val DOCUMENT_CHOOSER_CHANNEL = "mbg/open_document_chooser"
    private var eventSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val messenger = flutterEngine!!.dartExecutor.binaryMessenger

        EventChannel(messenger, EVENT_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, sink: EventChannel.EventSink?) {
                    eventSink = sink
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )

        MethodChannel(messenger, DOCUMENT_CHOOSER_CHANNEL).setMethodCallHandler { call, result ->
            if (call.method != "openWithChooser") {
                result.notImplemented()
                return@setMethodCallHandler
            }

            val path = call.argument<String>("path")
            val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
            val title = call.argument<String>("title") ?: "Öffnen mit"

            if (path.isNullOrBlank()) {
                result.error("INVALID_PATH", "Document path is empty", null)
                return@setMethodCallHandler
            }

            try {
                openDocumentChooser(path, mimeType, title)
                result.success(true)
            } catch (e: ActivityNotFoundException) {
                result.error("NO_APP", "No app found to open this document", null)
            } catch (e: Exception) {
                result.error("OPEN_FAILED", e.message, null)
            }
        }
    }

    private fun openDocumentChooser(path: String, mimeType: String, title: String) {
        val file = File(path)
        if (!file.exists()) {
            throw IllegalArgumentException("Document does not exist")
        }

        val uri: Uri = FileProvider.getUriForFile(
            this,
            packageName + ".fileProvider.com.crazecoder.openfile",
            file
        )
        val viewIntent = Intent(Intent.ACTION_VIEW).apply {
            addCategory(Intent.CATEGORY_DEFAULT)
            setDataAndType(uri, mimeType)
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }

        val resolveInfoList = packageManager.queryIntentActivities(viewIntent, 0)
        if (resolveInfoList.isEmpty()) {
            throw ActivityNotFoundException("No app found to open this document")
        }
        for (resolveInfo in resolveInfoList) {
            grantUriPermission(
                resolveInfo.activityInfo.packageName,
                uri,
                Intent.FLAG_GRANT_READ_URI_PERMISSION
            )
        }

        val chooser = Intent.createChooser(viewIntent, title).apply {
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(chooser)
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP -> {
                eventSink?.success("volume_up")
                return true // Prevents system volume change
            }
            KeyEvent.KEYCODE_VOLUME_DOWN -> {
                eventSink?.success("volume_down")
                return true // Prevents system volume change
            }
        }
        return super.onKeyDown(keyCode, event)
    }

    override fun onKeyUp(keyCode: Int, event: KeyEvent?): Boolean {
        return when (keyCode) {
            KeyEvent.KEYCODE_VOLUME_UP, KeyEvent.KEYCODE_VOLUME_DOWN -> true // Block key release event
            else -> super.onKeyUp(keyCode, event)
        }
    }
}
