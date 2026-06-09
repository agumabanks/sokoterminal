import '../../core/util/haptics.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_providers.dart';
import '../../core/theme/design_tokens.dart';
import '../../core/util/phone_normalizer.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _phoneController = TextEditingController();
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();

  bool _isLoading = false;
  String? _error;
  bool _codeSent = false;
  int _resendCooldown = 0;

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final phone = normalizeUgPhone(_phoneController.text.trim());
    if (phone.isEmpty) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/v2/auth/password/forget_request',
        data: {'email_or_phone': phone},
      );
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _isLoading = false;
      });
      _startResendCooldown();
      Haptics.impact();
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _extractMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _resendCode() async {
    if (_resendCooldown > 0) return;
    await _sendCode();
  }

  void _startResendCooldown() {
    _resendCooldown = 60;
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendCooldown--);
      return _resendCooldown > 0;
    });
  }

  Future<void> _resetPassword() async {
    final phone = normalizeUgPhone(_phoneController.text.trim());
    final code = _codeController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmController.text;

    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    if (password != confirm) {
      setState(() => _error = 'Passwords do not match');
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final api = ref.read(apiClientProvider);
      await api.post(
        '/v2/auth/password/confirm_reset',
        data: {
          'email_or_phone': phone,
          'verification_code': code,
          'password': password,
          'password_confirmation': confirm,
        },
      );
      if (!mounted) return;
      Haptics.impact();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset successful. Please log in.')),
      );
      context.go('/login');
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = _extractMessage(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  String _extractMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final msg = data['message']?.toString();
      if (msg != null && msg.isNotEmpty) return msg;
    }
    return e.message ?? 'Request failed';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: DesignTokens.paddingScreen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: DesignTokens.spaceLg),
              Text(
                _codeSent
                    ? 'Enter the verification code sent to your phone and choose a new password.'
                    : 'Enter your phone number and we\'ll send you a code to reset your password.',
                style: DesignTokens.textBody,
              ),
              const SizedBox(height: DesignTokens.spaceXl),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                enabled: !_codeSent,
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
              ),
              if (_codeSent) ...[
                const SizedBox(height: DesignTokens.spaceLg),
                TextField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(
                    labelText: '6-Digit Code',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    counterText: '',
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceLg),
                TextField(
                  controller: _confirmController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: DesignTokens.spaceMd),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: _resendCooldown > 0 || _isLoading ? null : _resendCode,
                    child: Text(
                      _resendCooldown > 0
                          ? 'Resend code in \$_resendCooldown s'
                          : 'Resend code',
                    ),
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: DesignTokens.spaceMd),
                Container(
                  padding: const EdgeInsets.all(DesignTokens.spaceMd),
                  decoration: BoxDecoration(
                    color: DesignTokens.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DesignTokens.error.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: DesignTokens.error),
                      const SizedBox(width: DesignTokens.spaceSm),
                      Expanded(
                        child: Text(
                          _error!,
                          style: DesignTokens.textSmall.copyWith(
                            color: DesignTokens.error,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: DesignTokens.spaceXl),
              ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (_codeSent ? _resetPassword : _sendCode),
                child: _isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(_codeSent ? 'Reset Password' : 'Send Code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
