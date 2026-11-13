import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Remembers what this account has reported, across restarts.
///
/// The server hides a post from everyone only once enough different people
/// report it, so until then it keeps coming back in the reporter's own feed.
/// These keys (`trip:<id>`, `comment:<id>`, `media:<id>`) are what keeps it
/// filtered out on the next refresh. Kept per account: a second account on
/// the same phone has reported nothing.
abstract class ReportedContentStore {
  Future<Set<String>> read(String userId);

  Future<void> write(String userId, Set<String> keys);
}

/// The real store, on the platform's preferences.
class PrefsReportedContentStore implements ReportedContentStore {
  const PrefsReportedContentStore();

  static String _key(String userId) => 'pluno.reported.$userId';

  /// Old entries go first once the list is this long; a reporter that busy
  /// has long since had the oldest ones hidden by the server anyway.
  static const _cap = 2000;

  @override
  Future<Set<String>> read(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key(userId)) ?? const <String>[]).toSet();
    } catch (error, stackTrace) {
      debugPrint('ReportedContentStore.read failed: $error\n$stackTrace');
      return <String>{};
    }
  }

  @override
  Future<void> write(String userId, Set<String> keys) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = keys.toList();
      await prefs.setStringList(
        _key(userId),
        list.length > _cap ? list.sublist(list.length - _cap) : list,
      );
    } catch (error, stackTrace) {
      // Still hidden for this run; it only comes back after a restart.
      debugPrint('ReportedContentStore.write failed: $error\n$stackTrace');
    }
  }
}

/// Forgets everything at exit. For tests.
class InMemoryReportedContentStore implements ReportedContentStore {
  InMemoryReportedContentStore([Map<String, Set<String>>? seed])
      : _byUser = {...?seed};

  final Map<String, Set<String>> _byUser;

  @override
  Future<Set<String>> read(String userId) async => {...?_byUser[userId]};

  @override
  Future<void> write(String userId, Set<String> keys) async =>
      _byUser[userId] = {...keys};
}
