import 'package:flutter/material.dart';
import '../services/remote_auth_service.dart';

/// Protected route widget that enforces role-based access control.
/// Redirects to dashboard if user doesn't have the required role.
class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final String requiredRole;
  final RemoteAuthService _authService = RemoteAuthService.instance;

  ProtectedRoute({
    Key? key,
    required this.child,
    required this.requiredRole,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _authService.userRole,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }

        if (snapshot.hasError) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
          });
          return const SizedBox.shrink();
        }

        final userRole = snapshot.data;

        // Check if user has required role
        if (userRole != requiredRole) {
          // Redirect to dashboard if role doesn't match
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.of(context).pushReplacementNamed('/persistent_dashboard');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('You need $requiredRole role to access this page'),
                backgroundColor: Colors.red,
              ),
            );
          });
          return const SizedBox.shrink();
        }

        return child;
      },
    );
  }
}
