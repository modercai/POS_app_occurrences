import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:occurences_pos/screens/home/home.dart';
import '../../services/auth_services.dart';


class VendorLogin extends StatefulWidget {
  final VoidCallback? onRegisterTap;

  const VendorLogin({Key? key, this.onRegisterTap}) : super(key: key);

  @override
  _VendorLoginState createState() => _VendorLoginState();
}

class _VendorLoginState extends State<VendorLogin> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  void _vendorSignIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      try {
        final authService = AuthService();
        final success = await authService.mobileLogin(
          _usernameController.text,
          _passwordController.text,
        );

        if (success && mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => EventPOSDashboard()),
          );
        } else {
          _showErrorSnackbar();
        }
      } catch (error) {
        _showErrorSnackbar();
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _showErrorSnackbar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Login Failed. Check your credentials.'),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 32),
                  Text(
                    'Vendor Portal',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: Colors.teal.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ).animate().slideY(duration: 400.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      prefixIcon: Icon(Icons.business_center_outlined, color: Colors.teal.shade300),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your vendor username'
                        : null,
                  ).animate().fadeIn(duration: 500.ms),

                  const SizedBox(height: 16),

                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Pin',
                      prefixIcon: Icon(Icons.lock_outline, color: Colors.teal.shade300),
                      suffixIcon: IconButton(
                        icon: Icon(_isPasswordVisible
                            ? Icons.visibility_off
                            : Icons.visibility),
                        onPressed: () => setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        }),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty
                        ? 'Please enter your password'
                        : null,
                  ).animate().fadeIn(duration: 600.ms),

                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => (){

                      },
                      child: Text(
                        'Forgot Password?',
                        style: TextStyle(color: Colors.teal.shade700),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  ElevatedButton(
                    onPressed: _isLoading ? null : _vendorSignIn,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade600,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                        'Sign In',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold
                        )
                    ),
                  ).animate().slideY(begin: 0.5, end: 0),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}