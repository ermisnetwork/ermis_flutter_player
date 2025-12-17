import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

class CreateStreamPage extends StatefulWidget {
  const CreateStreamPage({super.key, required this.player});

  final ErmisStreamPlayer? player;

  @override
  State<CreateStreamPage> createState() => _CreateStreamPageState();
}

class _CreateStreamPageState extends State<CreateStreamPage> {
  final TextEditingController _nameController = TextEditingController(
    text: 'demo-stream',
  );
  bool _isSubmitting = false;
  String? _result;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _createStream() async {
    final player = widget.player;
    if (player == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please configure token first')),
      );
      return;
    }
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter stream name')));
      return;
    }
    setState(() {
      _isSubmitting = true;
      _result = null;
    });
    try {
      final info = await player.createStream(streamName: name);
      if (!mounted) return;
      setState(() {
        _result = 'Created stream:\nID: ${info.streamId}\nLink: ${info.link}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _result = 'Error: $e';
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Stream')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Stream name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isSubmitting ? null : _createStream,
              icon: const Icon(Icons.cloud_upload),
              label: Text(_isSubmitting ? 'Creating...' : 'Create stream'),
            ),
            const SizedBox(height: 16),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(_result!, style: const TextStyle(fontSize: 14)),
              ),
          ],
        ),
      ),
    );
  }
}
