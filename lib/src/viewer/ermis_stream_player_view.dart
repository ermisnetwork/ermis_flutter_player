import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ErmisStreamPlayerView extends StatelessWidget {
  const ErmisStreamPlayerView({super.key});

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return UiKitView(
        viewType: 'fmp4_stream_player_view',
        layoutDirection: TextDirection.ltr,
        creationParams: null,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    if (Platform.isAndroid) {
      return AndroidView(
        viewType: 'fmp4_stream_player_view',
        layoutDirection: TextDirection.ltr,
        creationParams: null,
        creationParamsCodec: const StandardMessageCodec(),
      );
    }

    return const Center(child: Text('Platform not supported'));
  }
}
