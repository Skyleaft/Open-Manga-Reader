class QueueItem {
  final String id;
  final String jobName;
  final String state;
  final DateTime createdAt;

  QueueItem({
    required this.id,
    required this.jobName,
    required this.state,
    required this.createdAt,
  });

  factory QueueItem.fromJson(Map<String, dynamic> json) {
    return QueueItem(
      id: json['id'] as String? ?? 'unknown',
      jobName: json['jobName'] as String? ?? 'Unknown Job',
      state: json['state'] as String? ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : DateTime.now(),
    );
  }
}
