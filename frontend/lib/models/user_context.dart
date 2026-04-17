class UserContext {
  final String? selectedOwner;
  final String? selectedRepo;
  final int? selectedProjectNumber;

  const UserContext({
    this.selectedOwner,
    this.selectedRepo,
    this.selectedProjectNumber,
  });

  factory UserContext.fromJson(Map<String, dynamic> json) => UserContext(
        selectedOwner: json['selected_owner'] as String?,
        selectedRepo: json['selected_repo'] as String?,
        selectedProjectNumber: json['selected_project_number'] as int?,
      );

  Map<String, dynamic> toJson() => {
        'selected_owner': selectedOwner,
        'selected_repo': selectedRepo,
        'selected_project_number': selectedProjectNumber,
      };

  UserContext copyWith({
    String? selectedOwner,
    String? selectedRepo,
    int? selectedProjectNumber,
  }) =>
      UserContext(
        selectedOwner: selectedOwner ?? this.selectedOwner,
        selectedRepo: selectedRepo ?? this.selectedRepo,
        selectedProjectNumber:
            selectedProjectNumber ?? this.selectedProjectNumber,
      );

  bool get isComplete =>
      selectedOwner != null &&
      selectedRepo != null &&
      selectedProjectNumber != null;

  @override
  String toString() =>
      '${selectedOwner ?? '-'}/${selectedRepo ?? '-'} #${selectedProjectNumber ?? '-'}';
}
