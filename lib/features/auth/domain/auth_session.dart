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
      );

  /// The stand-in account used by tests and by the offline guest path.
  static const demo = AuthSession(
    displayName: 'PunGuide Traveler',
    handle: '@punguide.explorer',
    email: 'traveler@punguide.app',
    avatarImage:
        'https://images.unsplash.com/photo-1494790108377-be9c29b29330?crop=faces&cs=tinysrgb&fit=crop&fm=jpg&q=80&w=160&h=160',
  );

  final String displayName;
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
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AuthSession &&
      other.displayName == displayName &&
      other.handle == handle &&
      other.email == email &&
      other.avatarImage == avatarImage;

  @override
  int get hashCode => Object.hash(displayName, handle, email, avatarImage);
}
