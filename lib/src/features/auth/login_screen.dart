import '../../core/util/haptics.dart';
import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/country_codes.dart';
import 'auth_controller.dart';

/// "Steve Jobs" Style Phone-First Login
/// Flow: Phone -> Check -> PIN (if set) OR Password (if not set) OR Register (if new)
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _pageController = PageController();
  final _phoneController = TextEditingController();
  final _pinController = TextEditingController(); // Used for PIN or Password

  // Focus (purely UI/UX)
  final _phoneFocus = FocusNode();
  final _authFocus = FocusNode();

  CountryCode _selectedCountry = defaultCountryCode;

  bool _isLoading = false;
  String? _errorMessage;
  String? _userName;
  bool _hasPin = false; // Determined by backend check
  bool _hasPassword = true; // Seller must keep password configured.
  bool _usePassword = false; // Optional fallback when an account has PIN.
  bool _obscureText = true;
  bool _rememberDevice = false;

  int _failedAttempts = 0;
  int _cooldownSeconds = 0;
  Timer? _cooldownTimer;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  bool _authPage = false;

  @override
  void initState() {
    super.initState();

    // UI chrome: dark, clean
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 650),
      vsync: this,
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutQuart,
    );
    _fadeController.forward();

    _phoneController.addListener(_clearErrorOnInput);
    _pinController.addListener(_clearErrorOnInput);

    // Rebuild on focus change to show highlight
    _phoneFocus.addListener(() => mounted ? setState(() {}) : null);
    _authFocus.addListener(() => mounted ? setState(() {}) : null);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _phoneController.dispose();
    _pinController.dispose();
    _fadeController.dispose();
    _phoneFocus.dispose();
    _authFocus.dispose();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  void _clearErrorOnInput() {
    if (_errorMessage == null || !mounted) return;
    setState(() => _errorMessage = null);
  }

  void _startCooldown() {
    _cooldownSeconds = 30;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        _cooldownSeconds--;
        if (_cooldownSeconds <= 0) timer.cancel();
      });
    });
    if (mounted) setState(() {});
  }

  String get _normalizedPhone {
    final raw = _phoneController.text.trim();
    if (raw.isEmpty) return '';

    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return '';

    // If a full international number was entered, keep it unchanged.
    for (final country in eastAfricanCountryCodes) {
      if (digits.startsWith(country.digitCode) &&
          digits.length > country.digitCode.length + 5) {
        return digits;
      }
    }

    return normalizePhoneWithCountry(raw, _selectedCountry);
  }

  String _humanizeError(Object error) {
    if (error is DioException) {
      final responseData = error.response?.data;
      if (responseData is Map) {
        final map = Map<String, dynamic>.from(responseData);
        final message = map['message']?.toString().trim();
        final fieldErrors = map['errors'];
        if (fieldErrors is Map) {
          final lines = <String>[];
          for (final value in fieldErrors.values) {
            if (value is List) {
              lines.addAll(
                value
                    .map((entry) => entry.toString().trim())
                    .where((entry) => entry.isNotEmpty),
              );
            } else if (value != null) {
              final text = value.toString().trim();
              if (text.isNotEmpty) lines.add(text);
            }
          }
          final combined = lines.join('\n').trim();
          if (combined.isNotEmpty) return combined;
        }
        if (message != null && message.isNotEmpty) {
          return message;
        }
      }
      return error.message?.trim().isNotEmpty == true
          ? error.message!.trim()
          : 'Request failed. Please try again.';
    }

    final raw = error.toString().trim();
    if (raw.startsWith('Exception:')) {
      return raw.substring('Exception:'.length).trim();
    }
    return raw;
  }

  Future<void> _handlePhoneSubmit() async {
    if (_phoneController.text.trim().isEmpty) {
      _showError('Enter your phone number');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    Haptics.soft();

    try {
      final auth = ref.read(authControllerProvider.notifier);
      final result = await auth.checkUserExistence(_normalizedPhone);

      if (!mounted) return;

      if (result['exists'] == true) {
        // User exists -> Determine auth method
        final hasPin = result['has_pin'] == true;
        final hasPassword = result['has_password'] != false;
        if (!hasPassword) {
          setState(() => _isLoading = false);
          _showError(
            hasPin
                ? 'Account password is missing. Set/reset password on web first.'
                : 'Account is missing both password and PIN. Set password on web first.',
          );
          return;
        }

        setState(() {
          _userName = result['name'];
          _hasPin = hasPin;
          _hasPassword = hasPassword;
          _usePassword = false;
          _isLoading = false;
          _pinController.clear();
        });
        _nextPage();
        // Move focus to auth field (nice UX, no functional impact)
        Future.microtask(() {
          if (mounted) _authFocus.requestFocus();
        });
      } else {
        // User new -> Go to Register
        setState(() => _isLoading = false);
        context.go('/register', extra: {'phone': _normalizedPhone});
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(_humanizeError(e));
      }
    }
  }

  Future<void> _handleAuthSubmit() async {
    final input = _pinController.text;
    if (input.isEmpty) return;
    final usePinAuth = _hasPin && !_usePassword;

    if (usePinAuth && !RegExp(r'^\d{6}$').hasMatch(input)) {
      _showError('Invalid PIN');
      return;
    }

    if (!usePinAuth && input.length < 3) {
      _showError('Invalid Password');
      return;
    }

    if (usePinAuth && !_hasPassword) {
      _showError('Account password is missing. Reset password on web first.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    Haptics.impact();

    try {
      final auth = ref.read(authControllerProvider.notifier);

      if (usePinAuth) {
        // Login with PIN
        await auth.loginWithQuickPin(
          phone: _normalizedPhone,
          pin: input,
          rememberDevice: _rememberDevice,
        );
      } else {
        // Login with Password
        await auth.login(
          emailOrPhone: _normalizedPhone,
          password: input,
          rememberDevice: _rememberDevice,
        );
      }

      if (!mounted) return;

      final state = ref.read(authControllerProvider);
      if (state.status == AuthStatus.authenticated) {
        _failedAttempts = 0;
        if (!usePinAuth && !_hasPin) {
          // Offer PIN setup but allow skipping — don't block access
          final configured = await _promptPinSetupAfterPasswordLogin(input);
          if (!mounted) return;
          if (configured) {
            setState(() {
              _hasPin = true;
              _usePassword = false;
            });
          }
          // If not configured (skipped), proceed to home with password-only login
        }
        if (!mounted) return;
        Haptics.impact();
        context.go('/home/checkout');
      } else {
        setState(() => _isLoading = false);
        _showError(state.message ?? 'Authentication failed');
        _pinController.clear();
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startCooldown();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _showError(_humanizeError(e));
        _failedAttempts++;
        if (_failedAttempts >= 5) {
          _startCooldown();
        }
      }
    }
  }

  void _nextPage() {
    setState(() => _authPage = true);
    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuint,
    );
  }

  void _prevPage() {
    setState(() => _authPage = false);
    _pageController.previousPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuint,
    );
    setState(() => _errorMessage = null);

    // Restore focus to phone for quick edit
    Future.microtask(() {
      if (mounted) _phoneFocus.requestFocus();
    });
  }

  void _showError(String message) {
    final cleaned = message.trim();
    if (cleaned.isEmpty) return;
    setState(() => _errorMessage = cleaned);
    Haptics.warning();
  }

  Future<bool> _promptPinSetupAfterPasswordLogin(String password) async {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    String? localError;
    bool saving = false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            Future<void> submit() async {
              final pin = pinCtrl.text.trim();
              final confirm = confirmCtrl.text.trim();
              if (!RegExp(r'^\d{6}$').hasMatch(pin)) {
                setDialogState(
                  () => localError = 'PIN must be exactly 6 digits.',
                );
                return;
              }
              if (pin != confirm) {
                setDialogState(
                  () => localError = 'PIN confirmation does not match.',
                );
                return;
              }

              setDialogState(() {
                localError = null;
                saving = true;
              });

              try {
                await ref
                    .read(authControllerProvider.notifier)
                    .enableQuickPin(
                      phone: _normalizedPhone,
                      password: password,
                      pin: pin,
                    );
                if (!dialogContext.mounted) return;
                Navigator.of(dialogContext).pop(true);
              } catch (e) {
                setDialogState(() {
                  saving = false;
                  localError = _humanizeError(e);
                });
              }
            }

            return AlertDialog(
              backgroundColor: const Color(0xFF15151D),
              title: const Text(
                'Set Your POS PIN',
                style: TextStyle(color: Colors.white),
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Set a 6-digit PIN for faster logins. You can also skip this and always log in with your password.',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'New PIN',
                    ),
                  ),
                  TextField(
                    controller: confirmCtrl,
                    keyboardType: TextInputType.number,
                    obscureText: true,
                    maxLength: 6,
                    decoration: const InputDecoration(
                      counterText: '',
                      labelText: 'Confirm PIN',
                    ),
                  ),
                  if (localError != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      localError!,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: saving
                      ? null
                      : () => Navigator.of(dialogContext).pop(false),
                  child: const Text(
                    'Skip for now',
                    style: TextStyle(color: Colors.white54),
                  ),
                ),
                ElevatedButton(
                  onPressed: saving ? null : submit,
                  child: Text(saving ? 'Saving...' : 'Save PIN'),
                ),
              ],
            );
          },
        );
      },
    );

    pinCtrl.dispose();
    confirmCtrl.dispose();
    return result == true;
  }

  @override
  Widget build(BuildContext context) {
    final busy = _isLoading || (_authPage && _cooldownSeconds > 0);
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: const Color(0xfff7f8fa),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xff111820),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.storefront_outlined,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Soko Seller',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [_buildPhoneStep(), _buildAuthStep()],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: Semantics(
                              liveRegion: true,
                              child: Text(
                                _errorMessage!,
                                style: const TextStyle(
                                  color: Color(0xffa12222),
                                ),
                              ),
                            ),
                          ),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff111820),
                              foregroundColor: Colors.white,
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: busy
                                ? null
                                : (_authPage
                                      ? _handleAuthSubmit
                                      : _handlePhoneSubmit),
                            child: busy
                                ? Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Text(
                                        _cooldownSeconds > 0
                                            ? 'Try again in $_cooldownSeconds seconds'
                                            : 'Please wait…',
                                      ),
                                    ],
                                  )
                                : Text(_authPage ? 'Sign in' : 'Continue'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhoneStep() => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
    child: FadeTransition(
      opacity: _fadeAnimation,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Welcome to your shop',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Sell, track your stock and grow your business.',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xff51565f),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          const Text(
            'Phone number',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          _buildPhoneField(),
          const SizedBox(height: 12),
          const Text(
            'Use the number you registered with. New here? We’ll help you create an account.',
            style: TextStyle(color: Color(0xff51565f), height: 1.4),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: _isLoading ? null : () => context.go('/staff-login'),
            icon: const Icon(Icons.badge_outlined),
            label: const Text('I work in someone else’s shop'),
          ),
        ],
      ),
    ),
  );
  Widget _buildAuthStep() => SingleChildScrollView(
    keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextButton.icon(
          onPressed: _isLoading ? null : _prevPage,
          icon: const Icon(Icons.arrow_back),
          label: Text(_phoneController.text),
        ),
        const SizedBox(height: 20),
        Text(
          _userName == null ? 'Welcome back' : 'Hello, $_userName',
          style: const TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          _hasPin && !_usePassword
              ? 'Enter your 6-digit PIN to open your shop.'
              : 'Enter your password to open your shop.',
          style: const TextStyle(color: Color(0xff51565f), fontSize: 16),
        ),
        const SizedBox(height: 24),
        _buildAuthField(),
        const SizedBox(height: 12),
        _buildRememberDeviceRow(),
        if (_hasPin)
          TextButton(
            onPressed: _isLoading || _cooldownSeconds > 0
                ? null
                : () => setState(() {
                    _usePassword = !_usePassword;
                    _pinController.clear();
                  }),
            child: Text(_usePassword ? 'Use my PIN' : 'Use my password'),
          ),
        if (_usePassword)
          TextButton(
            onPressed: _isLoading || _cooldownSeconds > 0
                ? null
                : () => context.push('/forgot-password'),
            child: const Text('Forgot password?'),
          ),
      ],
    ),
  );
  InputDecoration _fieldDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: Colors.white,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffb8bec7)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xffb8bec7)),
    ),
  );
  Widget _buildPhoneField() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        label: 'Country: ${_selectedCountry.name}, ${_selectedCountry.code}',
        button: true,
        child: SizedBox(
          height: 60,
          child: OutlinedButton(
            onPressed: _isLoading ? null : _showCountryPicker,
            style: OutlinedButton.styleFrom(
              backgroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_selectedCountry.code),
                const Icon(Icons.keyboard_arrow_down, size: 18),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: TextFormField(
          controller: _phoneController,
          focusNode: _phoneFocus,
          enabled: !_isLoading,
          style: const TextStyle(fontSize: 18, color: Color(0xff111820)),
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(15),
          ],
          onFieldSubmitted: (_) => _handlePhoneSubmit(),
          decoration: _fieldDecoration('0700 123 456'),
        ),
      ),
    ],
  );
  Widget _buildAuthField() => TextFormField(
    controller: _pinController,
    focusNode: _authFocus,
    enabled: !_isLoading,
    style: TextStyle(
      fontSize: _hasPin && !_usePassword ? 24 : 18,
      color: const Color(0xff111820),
      letterSpacing: _hasPin && !_usePassword ? 5 : 0,
    ),
    keyboardType: _hasPin && !_usePassword
        ? TextInputType.number
        : TextInputType.visiblePassword,
    obscureText: _obscureText,
    textInputAction: TextInputAction.done,
    autofillHints: _hasPin && !_usePassword
        ? const []
        : const [AutofillHints.password],
    inputFormatters: _hasPin && !_usePassword
        ? [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ]
        : null,
    onFieldSubmitted: (_) => _handleAuthSubmit(),
    decoration:
        _fieldDecoration(
          _hasPin && !_usePassword ? '6-digit PIN' : 'Password',
        ).copyWith(
          suffixIcon: IconButton(
            tooltip: _obscureText
                ? 'Show PIN or password'
                : 'Hide PIN or password',
            icon: Icon(
              _obscureText
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
        ),
  );
  Widget _buildRememberDeviceRow() => CheckboxListTile(
    contentPadding: EdgeInsets.zero,
    controlAffinity: ListTileControlAffinity.leading,
    title: const Text('Remember this device for 90 days'),
    value: _rememberDevice,
    onChanged: _isLoading
        ? null
        : (v) {
            Haptics.selection();
            setState(() => _rememberDevice = v == true);
          },
  );

  Future<void> _showCountryPicker() async {
    final selected = await showCountryPickerBottomSheet(
      context,
      _selectedCountry,
    );
    if (selected != null) {
      setState(() => _selectedCountry = selected);
    }
  }
}
