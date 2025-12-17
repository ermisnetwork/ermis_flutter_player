import 'package:flutter/material.dart';

class TokenPage extends StatefulWidget {
  const TokenPage({
    super.key,
    required this.initialBaseUrl,
    required this.initialToken,
    required this.onSaved,
  });

  final String initialBaseUrl;
  final String? initialToken;
  final void Function({required String baseUrl, required String token}) onSaved;

  @override
  State<TokenPage> createState() => _TokenPageState();
}

class _TokenPageState extends State<TokenPage> {
  late final TextEditingController _baseUrlController;
  late final TextEditingController _tokenController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _baseUrlController = TextEditingController(text: widget.initialBaseUrl);
    _tokenController = TextEditingController(text: widget.initialToken ?? '');
  }

  @override
  void didUpdateWidget(TokenPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialBaseUrl != widget.initialBaseUrl) {
      _baseUrlController.text = widget.initialBaseUrl;
    }
    if (oldWidget.initialToken != widget.initialToken) {
      _tokenController.text = widget.initialToken ?? '';
    }
  }

  @override
  void dispose() {
    _baseUrlController.dispose();
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final baseUrl = _baseUrlController.text.trim();
    final token = _tokenController.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a token')));
      return;
    }
    setState(() => _saving = true);
    try {
      widget.onSaved(baseUrl: baseUrl, token: token);
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
            controller: _baseUrlController,
            decoration: const InputDecoration(
              labelText: 'API base URL',
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
