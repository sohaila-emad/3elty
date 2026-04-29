import 'remote_auth_service.dart';

/// Service for centralized permission checking.
/// Single source of truth for role-based access control.
class PermissionService {
  PermissionService._();
  static final PermissionService _instance = PermissionService._();

  factory PermissionService() => _instance;
  static PermissionService get instance => _instance;

  final RemoteAuthService _authService = RemoteAuthService.instance;

  /// Check if current user can add family members.
  /// Only admins can add members.
  Future<bool> canAddMember() async {
    final userRole = await _authService.userRole;
    return userRole == 'admin';
  }

  /// Check if current user can edit family members.
  /// Only admins can edit members.
  Future<bool> canEditMember() async {
    final userRole = await _authService.userRole;
    return userRole == 'admin';
  }

  /// Check if current user can delete family members.
  /// Only admins can delete members.
  Future<bool> canDeleteMember() async {
    final userRole = await _authService.userRole;
    return userRole == 'admin';
  }

  /// Check if current user can add health records.
  /// All authenticated members can add health records.
  Future<bool> canAddHealthRecord() async {
    final userRole = await _authService.userRole;
    return userRole != null; // Any authenticated user can add health records
  }

  /// Check if current user has admin privileges.
  Future<bool> isAdmin() async {
    final userRole = await _authService.userRole;
    return userRole == 'admin';
  }

  /// Get current user role (returns null if not authenticated).
  Future<String?> getUserRole() async {
    return await _authService.userRole;
  }
}
