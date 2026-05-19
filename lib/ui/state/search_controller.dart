import 'package:flutter/foundation.dart' hide Category;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/models.dart';

const String kAllCategoryPath = '__all__';

@immutable
class NoteSearchState {
  const NoteSearchState({this.query = '', this.category = kAllCategoryPath});

  final String query;
  final String category;

  NoteSearchState copyWith({String? query, String? category}) {
    return NoteSearchState(
      query: query ?? this.query,
      category: category ?? this.category,
    );
  }

  Iterable<Note> apply(Iterable<Note> notes) {
    final q = query.trim().toLowerCase();
    return notes.where((note) {
      if (category != kAllCategoryPath && note.categoryPath != category) {
        return false;
      }
      if (q.isEmpty) return true;
      if (note.title.toLowerCase().contains(q)) return true;
      if (note.tags.any((tag) => tag.toLowerCase().contains(q))) return true;
      if (note.templateName?.toLowerCase().contains(q) ?? false) return true;
      for (final rec in note.records) {
        if (rec.label.toLowerCase().contains(q)) return true;
        for (final value in rec.values.values) {
          if (value.toLowerCase().contains(q)) return true;
        }
      }
      return false;
    });
  }
}

class NoteSearchNotifier extends Notifier<NoteSearchState> {
  @override
  NoteSearchState build() => const NoteSearchState();

  void setQuery(String value) {
    if (state.query == value) return;
    state = state.copyWith(query: value);
  }

  void setCategory(String value) {
    if (state.category == value) return;
    state = state.copyWith(category: value);
  }

  void clear() {
    if (state.query.isEmpty && state.category == kAllCategoryPath) return;
    state = const NoteSearchState();
  }
}

final noteSearchProvider =
    NotifierProvider<NoteSearchNotifier, NoteSearchState>(
      NoteSearchNotifier.new,
    );
