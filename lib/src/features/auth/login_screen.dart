import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/sync_service.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _useEmail = false;
  bool _obscure = true;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final isLoading = auth.status == AuthStatus.loading;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      children: const [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: Color(0xFF0F1D40),
                          child: Icon(Icons.storefront, color: Colors.white),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Soko Seller',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text('Sign in to your shop', style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ToggleButtons(
                      borderRadius: BorderRadius.circular(12),
                      isSelected: [_useEmail == false, _useEmail == true],
                      onPressed: (index) => setState(() => _useEmail = index == 1),
                      children: const [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Phone'),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text('Email'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (!_useEmail)
                      TextFormField(
                        controller: _phoneController,
                        decoration: const InputDecoration(
                          labelText: 'Phone number',
                          hintText: '+2567xxxxxxx',
                          prefixIcon: Icon(Icons.phone_outlined),
                        ),
                        keyboardType: TextInputType.phone,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Enter your phone' : null,
                      )
                    else
                      TextFormField(
                        controller: _emailController,
                        decoration: const InputDecoration(
                          labelText: 'Email',
                          prefixIcon: Icon(Icons.mail_outline),
                        ),
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: (value) =>
                            value == null || value.trim().isEmpty ? 'Enter your email' : null,
                      ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (value) =>
                          value == null || value.isEmpty ? 'Required' : null,
                    ),
                    if (auth.status == AuthStatus.error && auth.message != null) ...[
                      const SizedBox(height: 12),
                      Text(auth.message!, style: const TextStyle(color: Colors.red)),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: isLoading
                          ? null
                          : () async {
                              if (!_formKey.currentState!.validate()) return;
                              final identifier =
                                  _useEmail ? _emailController.text.trim() : _phoneController.text.trim();
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .login(
                                    emailOrPhone: identifier,
                                    password: _passwordController.text.trim(),
                                  );
                              final state = ref.read(authControllerProvider);
                              if (state.status == AuthStatus.authenticated) {
                                // Start sync as soon as we are logged in.
                                ref.read(syncServiceProvider).start();
                                if (mounted) context.go('/home/checkout');
                              }
                            },
                      child: isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Text('Sign in'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Use the same credentials as your seller dashboard. Phone is preferred for faster entry.',
                      style: TextStyle(color: Colors.grey.shade600),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
