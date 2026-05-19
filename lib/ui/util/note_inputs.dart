import '../../domain/models/models.dart';
import '../../domain/repositories/repositories.dart';

NoteInput noteToInput(
  Note note, {
  String? title,
  String? icon,
  List<String>? tags,
  String? categoryPath,
  List<NoteRecord>? records,
  bool? isPinned,
  bool? isFavorite,
  String? body,
}) {
  return NoteInput(
    id: note.id,
    title: title ?? note.title,
    templateId: note.templateId,
    templateName: note.templateName,
    templateVersion: note.templateVersion,
    icon: icon ?? note.icon,
    tags: tags ?? note.tags,
    categoryPath: categoryPath ?? note.categoryPath,
    records: records ?? note.records,
    body: body ?? note.body,
    isPinned: isPinned ?? note.isPinned,
    isFavorite: isFavorite ?? note.isFavorite,
  );
}
