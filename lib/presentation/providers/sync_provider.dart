import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SyncStatus { idle, syncing, synced, offline }

/// Tracks the current backend sync status.
/// Updated by TaskNotifier on every CRUD operation.
final syncStatusProvider = StateProvider<SyncStatus>(
  (ref) => SyncStatus.idle,
);
