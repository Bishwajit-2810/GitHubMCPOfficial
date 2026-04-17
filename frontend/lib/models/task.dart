class TaskLabel {
  final String name;
  final String color;

  const TaskLabel({required this.name, required this.color});

  factory TaskLabel.fromJson(Map<String, dynamic> json) => TaskLabel(
        name: json['name'] as String? ?? '',
        color: json['color'] as String? ?? '#888888',
      );

  Map<String, dynamic> toJson() => {'name': name, 'color': color};
}

class Task {
  final String itemId;
  final String type;
  final String title;
  final String? status;
  final int? number;
  final String? state;
  final String? url;
  final List<String> assignees;
  final List<TaskLabel> labels;
  final String? createdAt;
  final String? updatedAt;

  const Task({
    required this.itemId,
    required this.type,
    required this.title,
    this.status,
    this.number,
    this.state,
    this.url,
    this.assignees = const [],
    this.labels = const [],
    this.createdAt,
    this.updatedAt,
  });

  factory Task.fromJson(Map<String, dynamic> json) => Task(
        itemId: json['item_id'] as String? ?? '',
        type: json['type'] as String? ?? 'ISSUE',
        title: json['title'] as String? ?? '(no title)',
        status: json['status'] as String?,
        number: json['number'] as int?,
        state: json['state'] as String?,
        url: json['url'] as String?,
        assignees: (json['assignees'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        labels: (json['labels'] as List<dynamic>?)
                ?.map((e) => TaskLabel.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [],
        createdAt: json['created_at'] as String?,
        updatedAt: json['updated_at'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'item_id': itemId,
        'type': type,
        'title': title,
        'status': status,
        'number': number,
        'state': state,
        'url': url,
        'assignees': assignees,
        'labels': labels.map((l) => l.toJson()).toList(),
        'created_at': createdAt,
        'updated_at': updatedAt,
      };
}
