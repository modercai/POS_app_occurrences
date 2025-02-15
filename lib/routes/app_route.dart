
import 'package:flutter/material.dart';
import 'package:occurences_pos/screens/home/home.dart';
import '../services/auth_services.dart';


class AppRouter {
  final AuthService authService;

  AppRouter({required this.authService});

  // Navigator for vendor-specific routes
  Widget vendorNavigator() {
    return Navigator(
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) =>  EventPOSDashboard(),
            );
        // Add other vendor-specific routes here
          default:
        }
      },
    );
  }

  // Helper method to handle navigation with user type check
  Future<void> navigateBasedOnUserType(BuildContext context, String route) async {
    final userData = await authService.checkAuthStatus();
    final userType = userData['user_type']?.toString().toUpperCase();

    if (!context.mounted) return;

    switch (userType) {
      case 'VENDOR':
        Navigator.of(context).pushNamed(route);
        break;
      case 'CUSTOMER':
        Navigator.of(context).pushNamed(route);
        break;
      default:
      // Handle invalid user type
        break;
    }
  }}