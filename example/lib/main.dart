import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:fmp4_stream_player/fmp4_stream_player.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  static const platform = MethodChannel("fmp4_stream_player");

  Future<void> startStream(String url) async {
    await platform.invokeMethod("startStreaming", {"url": url});
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Plugin example app')),
        body: Column(
          children: [
            Expanded(
              child:
                  Platform.isAndroid
                      ? AndroidView(
                        viewType: "fmp4_stream_player_view",
                        layoutDirection: TextDirection.ltr,
                      )
                      : UiKitView(viewType: "fmp4_stream_player_view"),
            ),
            ElevatedButton(
              onPressed: () {
                startStream(
                  "wss://streaming.ermis.network/stream-gate/software/Ermis-streaming/3e6873f2-cc88-4dac-b902-c86ff0ebeac8",
                );
              },
              child: const Text("Start Stream"),
            ),
          ],
        ),
      ),
    );
  }
}
