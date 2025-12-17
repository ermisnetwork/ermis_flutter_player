import 'package:flutter/material.dart';

class TokenPage extends StatefulWidget {
  const TokenPage({
    super.key,
    required this.initialApiBaseUrl,
    required this.initialStreamBaseUrl,
    required this.initialToken,
    required this.onSaved,
  });

  final String initialApiBaseUrl;
  final String initialStreamBaseUrl;
  final String? initialToken;
  final void Function({
    required String apiBaseUrl,
    required String streamBaseUrl,
    required String token,
  })
  onSaved;

  @override
  State<TokenPage> createState() => _TokenPageState();
}

class _TokenPageState extends State<TokenPage> {
  late final TextEditingController _apiBaseUrlController;
  late final TextEditingController _streamBaseUrlController;
  late final TextEditingController _tokenController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _apiBaseUrlController = TextEditingController(
      text: widget.initialApiBaseUrl,
    );
    _streamBaseUrlController = TextEditingController(
      text: widget.initialStreamBaseUrl,
    );
    _tokenController = TextEditingController(
      text:
          widget.initialToken ??
          'eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiMmFkNjZkNmMtZDkyOS00NmJkLThkNDktOWZlYTVkMTlhM2ExIiwiY2xpZW50X2lkIjoiYmE3Mzk4YzQtNjdhZi00YzgyLWIyZjMtNDZiOWNhM2Y4MTExIiwiYXBwX25hbWUiOiJFcm1pcy1zdHJlYW1pbmciLCJleHAiOjE3NjU5NTY4OTE2MzQsInJvbGVfbmFtZSI6ImNsaWVudF9hZG1pbiIsInBlcm1pc3Npb25zIjpbMSwyLDMsNCw1LDksMTEsMTIsMTMsMTQsMTUsMTYsMTcsMTgsMTksMjAsMjEsMjIsMjMsMjQsMjUsMjYsMjcsMjgsMjksMzAsMzEsMzIsMzMsMzQsMzUsMzYsMzcsMzgsMzksNDAsNDUsNDcsNDgsNDldfQ.DkSYDy6c_DVPxiOFJRkJ2PayTm4RvtIEvE1OpR2la4A',
    );
  }

  @override
  void didUpdateWidget(TokenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialApiBaseUrl != widget.initialApiBaseUrl) {
      _apiBaseUrlController.text = widget.initialApiBaseUrl;
    }
    if (oldWidget.initialStreamBaseUrl != widget.initialStreamBaseUrl) {
      _streamBaseUrlController.text = widget.initialStreamBaseUrl;
    }
    if (oldWidget.initialToken != widget.initialToken) {
      _tokenController.text = widget.initialToken ?? '';
    }
  }

  @override
  void dispose() {
    _apiBaseUrlController.dispose();
    _streamBaseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final apiBaseUrl = _apiBaseUrlController.text.trim();
    final streamBaseUrl = _streamBaseUrlController.text.trim();
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a token')));
      return;
    }
    setState(() => _saving = true);
    try {
      widget.onSaved(
        apiBaseUrl: apiBaseUrl,
        streamBaseUrl: streamBaseUrl,
        token: token,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Token saved')));
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _apiBaseUrlController,
            decoration: const InputDecoration(
              labelText: 'API base URL',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _streamBaseUrlController,
            decoration: const InputDecoration(
              labelText: 'Stream base URL (RTMP)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _tokenController,
            decoration: const InputDecoration(
              labelText: 'Bearer token',
              border: OutlineInputBorder(),
            ),
            maxLines: 5,
            minLines: 1,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.save),
            label: Text(_saving ? 'Saving...' : 'Save token'),
          ),
        ],
      ),
    );
  }
}
