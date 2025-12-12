import 'package:flutter/material.dart';
import 'package:rtmp_broadcaster/camera.dart';

import 'pages/broadcast_page.dart';
import 'pages/viewer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await _safeLoadCameras();
  runApp(MyApp(cameras: cameras));
}

Future<List<CameraDescription>> _safeLoadCameras() async {
  try {
    return await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Unable to load cameras: ${e.description ?? e.code}');
    return [];
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;

  const MyApp({super.key, required this.cameras});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: DefaultTabController(
        length: 2,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Ermis Stream Player'),
            bottom: const TabBar(
              tabs: [Tab(text: 'Viewer'), Tab(text: 'Broadcaster')],
            ),
          ),
          body: SafeArea(
            child: TabBarView(
              children: [const ViewerPage(), BroadcastPage(cameras: cameras)],
            ),
          ),
        ),
      ),
    );
  }
}
