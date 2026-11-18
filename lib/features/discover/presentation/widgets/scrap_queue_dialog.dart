import 'dart:async';
import 'package:material_ui/material_ui.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/manga_api_service.dart';
import '../../models/queue_item.dart';

class ScrapQueueDialog extends StatefulWidget {
  const ScrapQueueDialog({super.key});

  @override
  State<ScrapQueueDialog> createState() => _ScrapQueueDialogState();
}

class _ScrapQueueDialogState extends State<ScrapQueueDialog> {
  final apiService = getIt<MangaApiService>();
  Timer? _timer;
  List<QueueItem> _items = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchQueue();
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchQueue());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _fetchQueue() async {
    try {
      final rawData = await apiService.getScrapQueue();
      if (!mounted) return;

      setState(() {
        _items = rawData.map((e) => QueueItem.fromJson(e)).toList();
        _isLoading = false;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Scraping Queue'),
      content: SizedBox(
        width: double.maxFinite,
        height: 400,
        child: _buildContent(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null && _items.isEmpty) {
      return Center(child: Text('Error: $_error'));
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Queue is empty'));
    }

    return ListView.builder(
      itemCount: _items.length,
      itemBuilder: (context, index) {
        final item = _items[index];
        return ListTile(
          title: Text(item.jobName),
          subtitle: Text(
            'Added: ${item.createdAt.toLocal().toString().split('.')[0]}',
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: item.state == 'Processing'
                  ? Colors.orange.withValues(alpha: 0.1)
                  : item.state == 'Succeeded'
                  ? Colors.green.withValues(alpha: 0.1)
                  : Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              item.state,
              style: TextStyle(
                fontSize: 10,
                color: item.state == 'Processing'
                    ? Colors.orange
                    : item.state == 'Succeeded'
                    ? Colors.green
                    : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
