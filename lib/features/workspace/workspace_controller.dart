import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/auth_controller.dart';
import '../auth/data/current_user.dart';
import 'workspace.dart';

class WorkspaceState {
  const WorkspaceState({
    required this.available,
    required this.current,
    required this.lastLocations,
    required this.ready,
  });

  static const initial = WorkspaceState(
    available: [PlayerWorkspace()],
    current: PlayerWorkspace(),
    lastLocations: {},
    ready: false,
  );

  final List<Workspace> available;
  final Workspace current;

  /// Last screen visited in each workspace, by workspace key.
  final Map<String, String> lastLocations;

  /// False until the saved selection has been read, so the app never flashes
  /// the wrong workspace at launch.
  final bool ready;

  /// Where to go when entering [workspace]: where the user left it, or its home.
  String entryLocation(Workspace workspace) => lastLocations[workspace.key] ?? workspace.homeLocation;

  /// The available workspace that owns [location], if any.
  Workspace? ownerOf(String location) {
    for (final workspace in available) {
      if (workspace.owns(location)) return workspace;
    }
    return null;
  }

  WorkspaceState copyWith({Workspace? current, Map<String, String>? lastLocations, bool? ready}) => WorkspaceState(
        available: available,
        current: current ?? this.current,
        lastLocations: lastLocations ?? this.lastLocations,
        ready: ready ?? this.ready,
      );
}

final workspaceControllerProvider = NotifierProvider<WorkspaceController, WorkspaceState>(WorkspaceController.new);

/// Which workspace is open and where the user was in each, remembered per
/// account across launches (spec section 7: switching away and back returns
/// to the same organization, tournament and screen).
class WorkspaceController extends Notifier<WorkspaceState> {
  CurrentUser? _user;

  /// The last state for [_user], so a refreshed user object (new name,
  /// changed memberships) keeps the open workspace instead of reloading.
  WorkspaceState? _loaded;

  @override
  WorkspaceState build() {
    final user = ref.watch(currentUserProvider);
    final previousUser = _user;
    _user = user;
    if (user == null) {
      _loaded = null;
      return WorkspaceState.initial;
    }

    final available = workspacesFor(user);
    final loaded = _loaded;
    if (loaded != null && previousUser?.id == user.id) {
      return _reconcile(available, loaded.current.key, loaded.lastLocations);
    }

    Future.microtask(() => _load(user, available));
    return WorkspaceState(available: available, current: available.first, lastLocations: const {}, ready: false);
  }

  @override
  set state(WorkspaceState value) {
    super.state = value;
    if (value.ready) _loaded = value;
  }

  /// Keeps only what still points at a workspace the user has.
  WorkspaceState _reconcile(List<Workspace> available, Object? currentKey, Map<String, dynamic> savedLocations) {
    final locations = <String, String>{};
    for (final entry in savedLocations.entries) {
      final location = entry.value;
      if (location is String && available.any((w) => w.key == entry.key && w.owns(location))) {
        locations[entry.key] = location;
      }
    }
    final current = available.firstWhere((w) => w.key == currentKey, orElse: () => available.first);
    final next = WorkspaceState(available: available, current: current, lastLocations: locations, ready: true);
    _loaded = next;
    return next;
  }

  SharedPreferencesAsync get _prefs => ref.read(preferencesProvider);

  String _storageKey(String userId) => 'skorx.workspace.$userId';

  Future<void> _load(CurrentUser user, List<Workspace> available) async {
    Map<String, dynamic> saved = const {};
    try {
      final raw = await _prefs.getString(_storageKey(user.id));
      if (raw != null) saved = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Unreadable saved state: start from the Player workspace.
    }
    if (_user?.id != user.id) return;

    // Drops anything pointing at a workspace the user no longer has
    // (membership removed since last launch).
    state = _reconcile(available, saved['current'], (saved['locations'] as Map<String, dynamic>?) ?? const {});
  }

  /// Called on every navigation. Keeps the current workspace in step with
  /// the screen shown (including deep links into another workspace) and
  /// remembers the screen for next time.
  void recordLocation(String location) {
    final owner = state.ownerOf(location);
    if (owner == null || !state.ready) return;
    if (owner.key == state.current.key && state.lastLocations[owner.key] == location) return;
    state = state.copyWith(current: owner, lastLocations: {...state.lastLocations, owner.key: location});
    _save();
  }

  Future<void> _save() async {
    final user = _user;
    if (user == null) return;
    await _prefs.setString(
      _storageKey(user.id),
      jsonEncode({'current': state.current.key, 'locations': state.lastLocations}),
    );
  }
}
