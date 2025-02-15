import 'package:flutter/material.dart';
import 'package:occurences_pos/screens/login/login.dart';
import 'auth_services.dart';

class AuthMiddleware extends StatefulWidget {
  final Widget vendorApp;
  final AuthService authService;

  const AuthMiddleware({
    Key? key,
    required this.vendorApp,
    required this.authService,
  }) : super(key: key);

  @override
  State<AuthMiddleware> createState() => _AuthMiddlewareState();
}

class _AuthMiddlewareState extends State<AuthMiddleware> {
  late Future<bool> _authCheckFuture;

  @override
  void initState() {
    super.initState();
    _authCheckFuture = widget.authService.isAuthenticatedWithValidToken();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _authCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.data == true) {
          return widget.vendorApp;
        }

        return VendorLogin();
      },
    );
  }
}
