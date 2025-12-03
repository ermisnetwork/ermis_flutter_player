package com.yourcompany.fmp4_stream_player

import android.util.Log
import okhttp3.*
import org.json.JSONObject
import java.io.IOException

object FMP4StreamPlayerApi {

    fun startStreaming(
        streamId: String,
        token: String,
        onSuccess: (workerUrl: String) -> Unit,
        onFailure: (message: String) -> Unit
    ) {
        val client = OkHttpClient()
        val urlInfo = "https://streaming.ermis.network/stream-gate/streams/$streamId"
        val request = Request.Builder()
            .url(urlInfo)
            .addHeader("accept", "application/json")
            .addHeader("Authorization", "Bearer $token")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("FMP4", "API failure: ${e.message}")
                onFailure("API failure: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                val body = response.body?.string()
                Log.e("FMP4", "API failure: ${response}")

                if (body == null) {
                    onFailure("Empty response from API")
                    return
                }
                if (!response.isSuccessful) {
                    onFailure("API returned status code ${response.code}")
                    return
                }

                try {
                    val json = JSONObject(body)
                    val isLive = json.optBoolean("is_live", false)
                    val isPublished = json.optBoolean("is_published", false)
                    Log.d("FMP4", "isLive=$isLive, isPublished=$isPublished")
                    if (!isLive || !isPublished) {
                        onFailure("Stream is not live or not published")
                        return
                    }
                    fetchWsUrl(streamId, token, onSuccess, onFailure)
                } catch (e: Exception) {
                    onFailure("Failed to parse API response: ${e.message}")
                }
            }
        })
    }

    private fun fetchWsUrl(
        streamId: String,
        token: String,
        onSuccess: (workerUrl: String) -> Unit,
        onFailure: (message: String) -> Unit
    ) {
        val client = OkHttpClient()
        val urlWs = "https://streaming.ermis.network/stream-gate/streams/$streamId/ws-url"
        val request = Request.Builder()
            .url(urlWs)
            .addHeader("accept", "application/json")
            .addHeader("Authorization", "Bearer $token")
            .build()

        client.newCall(request).enqueue(object : Callback {
            override fun onFailure(call: Call, e: IOException) {
                Log.e("FMP4", "WS_URL failure: ${e.message}")
                onFailure("WS_URL failure: ${e.message}")
            }

            override fun onResponse(call: Call, response: Response) {
                val body = response.body?.string()
                if (body == null) {
                    onFailure("Empty response from WS_URL API")
                    return
                }
                if (!response.isSuccessful) {
                    onFailure("WS_URL API returned status code ${response.code}")
                    return
                }

                try {
                    val json = JSONObject(body)
                    val workerUrl = json.optString("worker_url", "")
                    if (workerUrl.isNotEmpty()) {
                        onSuccess(workerUrl)
                    } else {
                        onFailure("worker_url is empty")
                    }
                } catch (e: Exception) {
                    onFailure("Failed to parse WS_URL response: ${e.message}")
                }
            }
        })
    }
}