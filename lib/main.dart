import 'package:flutter/material.dart';
import 'package:occurences_pos/routes/app_route.dart';
import 'package:occurences_pos/services/auth-middlware.dart';
import 'package:occurences_pos/services/auth_services.dart';
import 'package:occurences_pos/services/cart_provider.dart';
import 'package:provider/provider.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<AuthService>(create: (_) => AuthService()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        Provider<AppRouter>(
          create: (context) => AppRouter(
            authService: context.read<AuthService>(),
          ),
        ),
      ],
      child: Builder(
        builder: (context) {
          final appRouter = context.read<AppRouter>();

          return MaterialApp(
            debugShowCheckedModeBanner: false,
            title: 'Occurrences App',
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
              useMaterial3: true,
            ),
            home: AuthMiddleware(
              authService: context.read<AuthService>(),
              vendorApp: appRouter.vendorNavigator(),
            ),
          );
        },
      ),
    );
  }
}