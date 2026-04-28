import 'services/remote_auth_service.dart';

/// Legacy wrapper around RemoteAuthService.
/// Kept for backward compatibility with persistent_dashboard.dart.
class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final RemoteAuthService _remote = RemoteAuthService.instance;

  Future<void> signOut() => _remote.signOut();

  Future<bool> isSignedIn() => _remote.isSignedIn();

  Future<String?> get familyId => _remote.familyId;

  Future<String?> get userRole => _remote.userRole;
}
