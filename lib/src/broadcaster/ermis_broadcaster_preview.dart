import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';

import 'ermis_broadcaster_controller.dart';

class ErmisBroadcasterPreview extends StatelessWidget {
  final ErmisBroadcasterController controller;

  const ErmisBroadcasterPreview({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final cameraController = controller.cameraController;
        if (cameraController == null ||
            cameraController.value.isInitialized != true) {
          return const _PreviewPlaceholder();
        }

        return AspectRatio(
          aspectRatio: cameraController.value.aspectRatio,
          child: CameraPreview(cameraController),
        );
      },
    );
  }
}

class _PreviewPlaceholder extends StatelessWidget {
  const _PreviewPlaceholder();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(colorScheme.primary),
            ),
            const SizedBox(height: 12),
            Text(
              'Camera preview not ready',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
