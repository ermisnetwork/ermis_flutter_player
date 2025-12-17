import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

import 'pages/broadcast_page.dart';
import 'pages/create_stream_page.dart';
import 'pages/stream_list_page.dart';
import 'pages/token_page.dart';
import 'pages/update_stream_page.dart';
import 'pages/viewer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ErmisDemoHome());
  }
}

class ErmisDemoHome extends StatefulWidget {
  const ErmisDemoHome({super.key});

  @override
  State<ErmisDemoHome> createState() => _ErmisDemoHomeState();
}

class _ErmisDemoHomeState extends State<ErmisDemoHome> {
  static const String _defaultBaseUrl = 'https://streaming.ermis.network';

  String _baseUrl = _defaultBaseUrl;
  String? _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMmFkNjZkNmMtZDkyOS00NmJkLThkNDktOWZlYTVkMTlhM2ExIiwiY2xpZW50X2lkIjoiYmE3Mzk4YzQtNjdhZi00YzgyLWIyZjMtNDZiOWNhM2Y4MTExIiwiYXBwX25hbWUiOiJFcm1pcy1zdHJlYW1pbmciLCJleHAiOjE3NjU5NTY4OTE2MzQsInJvbGVfbmFtZSI6ImNsaWVudF9hZG1pbiIsInBlcm1pc3Npb25zIjpbMSwyLDMsNCw1LDksMTEsMTIsMTMsMTQsMTUsMTYsMTcsMTgsMTksMjAsMjEsMjIsMjMsMjQsMjUsMjYsMjcsMjgsMjksMzAsMzEsMzIsMzMsMzQsMzUsMzYsMzcsMzgsMzksNDAsNDUsNDcsNDgsNDldfQ.DkSYDy6c_DVPxiOFJRkJ2PayTm4RvtIEvE1OpR2la4A';
  ErmisStreamPlayer? _player;

  void _updateAuth({required String baseUrl, required String token}) {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;
    setState(() {
      _baseUrl = baseUrl.trim().isEmpty ? _defaultBaseUrl : baseUrl.trim();
      _token = trimmedToken;
      ErmisStreamPlayer(
        config: ErmisStreamConfig(
          apiBaseUrl: Uri.parse(_baseUrl),
          authTokenProvider: () => trimmedToken,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ermis Stream Player'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Auth'),
              Tab(text: 'Streams'),
              Tab(text: 'Create'),
              Tab(text: 'Update'),
              Tab(text: 'Viewer'),
              Tab(text: 'Broadcaster'),
            ],
          ),
        ),
        body: SafeArea(
          child: TabBarView(
            children: [
              TokenPage(
                initialBaseUrl: _baseUrl,
                initialToken: _token,
                onSaved: _updateAuth,
              ),
              StreamListPage(player: _player),
              CreateStreamPage(player: _player),
              UpdateStreamPage(player: _player),
              const ViewerPage(),
              const BroadcastPage(),
            ],
          ),
        ),
      ),
    );
  }
}
