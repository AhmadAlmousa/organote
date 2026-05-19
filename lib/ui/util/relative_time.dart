String formatRelativeTime(DateTime? value, {DateTime? now}) {
  if (value == null) return '—';
  final reference = now ?? DateTime.now();
  final diff = reference.difference(value);
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 2) return '1 min';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min';
  if (diff.inHours < 2) return '1 h';
  if (diff.inHours < 24) return '${diff.inHours} h';
  if (diff.inDays < 2) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} d';
  final weeks = diff.inDays ~/ 7;
  if (weeks < 5) return '${weeks}w';
  final months = diff.inDays ~/ 30;
  if (months < 12) return '${months}mo';
  final years = diff.inDays ~/ 365;
  return '${years}y';
}
