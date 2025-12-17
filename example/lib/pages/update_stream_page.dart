import 'package:ermis_stream_player/ermis_stream_player.dart';
import 'package:flutter/material.dart';

class UpdateStreamPage extends StatefulWidget {
  const UpdateStreamPage({super.key, required this.player});

  final ErmisStreamPlayer? player;

  @override
  State<UpdateStreamPage> createState() => _UpdateStreamPageState();
}

class _UpdateStreamPageState extends State<UpdateStreamPage> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _methodController = TextEditingController(
    text: 'software',
  );
  final TextEditingController _streamKeyController = TextEditingController(
    text: '',
  );
  bool? _isLive;
  bool _isUpdating = false;
  String? _result;

  @override
  void dispose() {
    _idController.dispose();
    _nameController.dispose();
    _methodController.dispose();
    _streamKeyController.dispose();
    super.dispose();
  }

  Future<void> _updateStream() async {
    final player = widget.player;
    if (player == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Configure token first')));
      return;
    }
    final id = _idController.text.trim();
    if (id.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Stream ID is required')));
      return;
    }
    final request = ErmisStreamUpdateRequest(
      streamName:
          _nameController.text.trim().isEmpty
              ? null
              : _nameController.text.trim(),
      streamMethod:
          _methodController.text.trim().isEmpty
              ? null
              : _methodController.text.trim(),
      streamKey:
          _streamKeyController.text.trim().isEmpty
              ? null
              : _streamKeyController.text.trim(),
      isLive: _isLive,
    );

    if (!request.hasData) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter at least one field to update')),
      );
      return;
    }

    setState(() {
      _isUpdating = true;
      _result = null;
    });

    try {
      final info = await player.updateStream(streamId: id, request: request);
      if (!mounted) return;
      setState(() {
        _result =
            'Updated stream:\n'
            'Name: ${info.streamName}\n'
            'Live: ${info.isLive}\n'
            'Method: ${info.streamMethod}';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _idController,
              decoration: const InputDecoration(
                labelText: 'Stream ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Stream name (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _methodController,
              decoration: const InputDecoration(
                labelText: 'Stream method (browser/software)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _streamKeyController,
              decoration: const InputDecoration(
                labelText: 'Stream key (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<bool?>(
              value: _isLive,
              items: const [
                DropdownMenuItem(
                  value: null,
                  child: Text('is_live: unchanged'),
                ),
                DropdownMenuItem(value: true, child: Text('is_live: true')),
                DropdownMenuItem(value: false, child: Text('is_live: false')),
              ],
              onChanged: (value) => setState(() => _isLive = value),
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isUpdating ? null : _updateStream,
              icon: const Icon(Icons.save),
              label: Text(_isUpdating ? 'Updating...' : 'Update stream'),
            ),
            const SizedBox(height: 16),
            if (_result != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade400),
                ),
                child: Text(_result!),
              ),
          ],
        ),
      ),
    );
  }
}
