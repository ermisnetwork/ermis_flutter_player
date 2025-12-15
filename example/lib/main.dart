import 'package:example/pages/viewer_page.dart';
import 'package:flutter/material.dart';

import 'pages/broadcast_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

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
          body: const SafeArea(
            child: TabBarView(children: [ViewerPage(), BroadcastPage()]),
          ),
        ),
      ),
    );
  }
}
