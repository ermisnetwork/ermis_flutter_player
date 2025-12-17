import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

import 'pages/broadcast_page.dart';
import 'pages/create_stream_page.dart';
import 'pages/stream_list_page.dart';
import 'pages/token_page.dart';
import 'pages/viewer_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static const String homeRoute = '/';
  static const String createStreamRoute = '/create_stream';

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      initialRoute: homeRoute,
      routes: {homeRoute: (_) => const ErmisDemoHome()},
      onGenerateRoute: (settings) {
        if (settings.name == createStreamRoute &&
            settings.arguments is CreateStreamArguments) {
          final args = settings.arguments! as CreateStreamArguments;
          return MaterialPageRoute(
            builder: (_) => CreateStreamPage(player: args.player),
          );
        }
        return null;
      },
    );
  }
}

class ErmisDemoHome extends StatefulWidget {
  const ErmisDemoHome({super.key});

  @override
  State<ErmisDemoHome> createState() => _ErmisDemoHomeState();
}

class _ErmisDemoHomeState extends State<ErmisDemoHome> {
  static const String _defaultApiBaseUrl = 'https://streaming.ermis.network';
  static const String _defaultStreamBaseUrl =
      'rtmps://streaming.ermis.network:1939';

  String _apiBaseUrl = _defaultApiBaseUrl;
  String _streamBaseUrl = _defaultStreamBaseUrl;
  String? _token =
      'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMmFkNjZkNmMtZDkyOS00NmJkLThkNDktOWZlYTVkMTlhM2ExIiwiY2xpZW50X2lkIjoiYmE3Mzk4YzQtNjdhZi00YzgyLWIyZjMtNDZiOWNhM2Y4MTExIiwiYXBwX25hbWUiOiJFcm1pcy1zdHJlYW1pbmciLCJleHAiOjE3NjU5NTY4OTE2MzQsInJvbGVfbmFtZSI6ImNsaWVudF9hZG1pbiIsInBlcm1pc3Npb25zIjpbMSwyLDMsNCw1LDksMTEsMTIsMTMsMTQsMTUsMTYsMTcsMTgsMTksMjAsMjEsMjIsMjMsMjQsMjUsMjYsMjcsMjgsMjksMzAsMzEsMzIsMzMsMzQsMzUsMzYsMzcsMzgsMzksNDAsNDUsNDcsNDgsNDldfQ.DkSYDy6c_DVPxiOFJRkJ2PayTm4RvtIEvE1OpR2la4A';
  ErmisStreamPlayer? _player;

  Future<String> _provideToken() async => _token ?? '';

  @override
  void initState() {
    super.initState();
    _player = ErmisStreamPlayer(
      config: ErmisStreamConfig(
        apiBaseUrl: Uri.parse(_apiBaseUrl),
        streamBaseUrl: Uri.parse(_streamBaseUrl),
        authTokenProvider: _provideToken,
      ),
    );
  }

  void _updateAuth({
    required String apiBaseUrl,
    required String streamBaseUrl,
    required String token,
  }) {
    final trimmedToken = token.trim();
    if (trimmedToken.isEmpty) return;
    setState(() {
      final nextApiUrl =
          apiBaseUrl.trim().isEmpty ? _defaultApiBaseUrl : apiBaseUrl.trim();
      final nextStreamUrl =
          streamBaseUrl.trim().isEmpty
              ? _defaultStreamBaseUrl
              : streamBaseUrl.trim();
      _apiBaseUrl = nextApiUrl;
      _streamBaseUrl = nextStreamUrl;
      _token = trimmedToken;
      _player = ErmisStreamPlayer(
        config: ErmisStreamConfig(
          apiBaseUrl: Uri.parse(_apiBaseUrl),
          streamBaseUrl: Uri.parse(_streamBaseUrl),
          authTokenProvider: _provideToken,
        ),
      );
    });
  }

  void _openCreateStream() {
    final player = _player;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure token first')),
      );
      return;
    }
    Navigator.of(context).pushNamed(
      MyApp.createStreamRoute,
      arguments: CreateStreamArguments(player: player),
    );
  }

  void _openBroadcaster(ErmisStreamInfo stream) {
    final player = _player;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure token first')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => BroadcastPage(
              streamInfo: stream,
              controllerFactory: player.broadcasterFactory,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ermis Stream Player'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Settings'),
              Tab(text: 'Streams'),
              Tab(text: 'Viewer'),
            ],
          ),
        ),
        body: SafeArea(
          child: Material(
            child: TabBarView(
              children: [
                TokenPage(
                  initialApiBaseUrl: _apiBaseUrl,
                  initialStreamBaseUrl: _streamBaseUrl,
                  initialToken: _token,
                  onSaved: _updateAuth,
                ),
                StreamListPage(
                  player: _player,
                  onCreateStream: _openCreateStream,
                  onStreamSelected: _openBroadcaster,
                ),
                const ViewerPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CreateStreamArguments {
  const CreateStreamArguments({required this.player});

  final ErmisStreamPlayer player;
}
