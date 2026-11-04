import 'package:flutter/foundation.dart';

import '../../../core/api/pluno_api.dart';

/// A signed-in user. Deliberately thin: it carries only what the UI shows
/// today, so swapping the local stub for a real backend session touches this
/// file and the controller, not the screens.
@immutable
class AuthSession {
  const AuthSession({
    required this.displayName,
    required this.handle,
    required this.email,
    this.avatarImage,
    this.name,
  });

  /// The signed-in account as the API describes it.
  ///
  /// The API has no `handle` — it is the username, shown with a leading `@`.
  /// A username/password account has no email until it signs in with Google,
  /// so [email] can be empty.
  factory AuthSession.fromUser(AuthUser user) => AuthSession(
        displayName: user.displayName,
        handle: '@${user.username}',
        email: user.email ?? '',
        avatarImage: user.avatarUrl,
        name: user.name,
      );

  /// The stand-in account used by tests and by the offline guest path.
  static const demo = AuthSession(
    displayName: 'PunGuide Traveler',
    handle: '@punguide.explorer',
    email: 'traveler@punguide.app',
    avatarImage:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?crop=faces&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=160&h=160',
  );

  /// What to print for this account: the name they set, or their username
  /// when they never did.
  final String displayName;

  /// The display name **as the account actually holds it** — null for an
  /// account that has never set one, which is every username registration
  /// until the traveller does.
  ///
  /// Kept apart from [displayName] because the two differ exactly where it
  /// matters: an edit form pre-filled from [displayName] would offer the
  /// username as if it were the name, and saving unchanged would quietly
  /// make it one.
  final String? name;

  final String handle;
  final String email;
  final String? avatarImage;

  /// The avatar lives at one fixed storage key per user
  /// (`users/{userId}/avatar.webp`), so uploading a new picture overwrites the
  /// file without changing the URL — and every image cache keyed on that URL
  /// keeps serving the old one. Call this after an upload, never on a plain
  /// read, or nothing would ever cache.
  AuthSession withFreshAvatar() {
    final url = avatarImage;
    if (url == null || url.isEmpty) return this;
    final separator = url.contains('?') ? '&' : '?';
    return AuthSession(
      displayName: displayName,
      handle: handle,
      email: email,
      avatarImage: '$url${separator}t=${DateTime.now().millisecondsSinceEpoch}',
      name: name,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.displayName == displayName &&
      other.handle == handle &&
      other.email == email &&
      other.avatarImage == avatarImage &&
      other.name == name;

  @override
  int get hashCode =>
      Object.hash(displayName, handle, email, avatarImage, name);
}
