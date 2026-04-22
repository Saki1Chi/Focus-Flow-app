import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/category_model.dart';
import '../../services/api_service.dart';

// ── State ─────────────────────────────────────────────────────────────────────

class CategoryState {
  final List<Category> categories;
  final bool isLoading;
  final bool hasError;

  const CategoryState({
    this.categories = const [],
    this.isLoading = false,
    this.hasError = false,
  });

  CategoryState copyWith({
    List<Category>? categories,
    bool? isLoading,
    bool? hasError,
  }) =>
      CategoryState(
        categories: categories ?? this.categories,
        isLoading: isLoading ?? this.isLoading,
        hasError: hasError ?? this.hasError,
      );

  Category? byId(int? id) =>
      id == null ? null : categories.where((c) => c.id == id).firstOrNull;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class CategoryNotifier extends StateNotifier<CategoryState> {
  CategoryNotifier() : super(const CategoryState()) {
    load();
  }

  Future<void> load() async {
    state = state.copyWith(isLoading: true, hasError: false);
    try {
      final cats = await ApiService().getCategories();
      state = state.copyWith(categories: cats, isLoading: false);
    } catch (_) {
      state = state.copyWith(isLoading: false, hasError: true);
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final categoryProvider =
    StateNotifierProvider<CategoryNotifier, CategoryState>(
  (ref) => CategoryNotifier(),
);
