import '../../core/util/haptics.dart';
import 'dart:async';
import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/util/country_codes.dart';
import 'auth_controller.dart';
import '../../core/theme/design_tokens.dart';

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

  // Soko brand palette — aligned with DesignTokens
  static const Color _bg = DesignTokens.brandPrimary;
  static const Color _accent = DesignTokens.brandAccent;
  static const Color _surface = DesignTokens.brandPrimary;
  static const Color _stroke = Color(0x22FFFFFF);

  @override
  void initState() {
    super.initState();

    // UI chrome: dark, clean
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.black,
        systemNavigationBarIconBrightness: Brightness.light,
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
                value.map((entry) => entry.toString().trim()).where(
                  (entry) => entry.isNotEmpty,
                ),
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
    _pageController.nextPage(
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutQuint,
    );
  }

  void _prevPage() {
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
    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: Scaffold(
        backgroundColor: _bg,
        body: Stack(
          children: [
            // Base gradient (subtle)
            Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [_bg, DesignTokens.brandPrimary, _bg],
                ),
              ),
            ),

            // Accent glow (soft, minimal)
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(color: _accent.withValues(alpha: 0.16), size: 420),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(
                color: Colors.white.withValues(alpha: 0.06),
                size: 520,
              ),
            ),

            SafeArea(
              child: Column(
                children: [
                  _buildHeader(),
                  Expanded(
                    child: Center(
                      // Keeps the layout “designed” on tablets/web without changing behavior
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: PageView(
                          controller: _pageController,
                          physics: const NeverScrollableScrollPhysics(),
                          children: [_buildPhoneStep(), _buildAuthStep()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error pill
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              right: 16,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                child: _errorMessage == null
                    ? const SizedBox.shrink()
                    : _buildErrorSnack(key: ValueKey(_errorMessage)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
      child: Row(
        children: [
          FadeTransition(
            opacity: _fadeAnimation,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: _surface.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Text(
                'Sign in',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.9),
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Soko24',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Seller Terminal',
              style: TextStyle(
                color: _accent.withValues(alpha: 0.95),
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.6,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Sell in-store, online, and offline — one terminal for your whole business.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 15,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 22),
            const _LoginFeatureRow(),
            const SizedBox(height: 36),
            Text(
              'Enter your phone number',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            _buildPhoneField(),
            const SizedBox(height: 28),
            _MainButton(
              text: 'Continue',
              isLoading: _isLoading,
              onTap: _handlePhoneSubmit,
            ),
            const SizedBox(height: 10),
            Text(
              'We’ll check if you already have an account.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthStep() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _prevPage,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.arrow_back,
                      color: Colors.white.withValues(alpha: 0.55),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _phoneController.text,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 14,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              _userName != null
                  ? 'Hello, $_userName'
                  : ((_hasPin && !_usePassword) ? 'Enter PIN' : 'Password'),
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              (_hasPin && !_usePassword)
                  ? 'Enter your 6-digit access PIN.'
                  : 'Enter your password to login.',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.62),
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 44),
            _buildAuthField(),
            const SizedBox(height: 16),
            _buildRememberDeviceRow(),
            const SizedBox(height: 28),
            _MainButton(
              text: (_hasPin && !_usePassword)
                  ? 'Unlock'
                  : _cooldownSeconds > 0
                      ? 'Wait $_cooldownSeconds s'
                      : 'Login',
              isLoading: _isLoading || _cooldownSeconds > 0,
              onTap: () { _handleAuthSubmit(); },
            ),
            if (_hasPin) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_isLoading || _cooldownSeconds > 0)
                    ? null
                    : () {
                        setState(() {
                          _usePassword = !_usePassword;
                          _pinController.clear();
                        });
                      },
                child: Text(
                  _usePassword ? 'Use PIN instead' : 'Use password instead',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                ),
              ),
            ],
            if (_usePassword) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: (_isLoading || _cooldownSeconds > 0)
                    ? null
                    : () => context.push('/forgot-password'),
                child: Text(
                  'Forgot password?',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPhoneField() {
    final bool focused = _phoneFocus.hasFocus;

    return _GlassField(
      focused: focused,
      child: Row(
        children: [
          InkWell(
            onTap: () => _showCountryPicker(),
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(22),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Text(
                    _selectedCountry.flag,
                    style: const TextStyle(fontSize: 20),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 16,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ],
              ),
            ),
          ),
          Container(
            width: 1,
            height: 26,
            color: Colors.white.withValues(alpha: 0.10),
          ),
          Expanded(
            child: TextFormField(
              focusNode: _phoneFocus,
              controller: _phoneController,
              cursorColor: Colors.white,
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.telephoneNumber],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(15),
              ],
              onFieldSubmitted: (_) => _handlePhoneSubmit(),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 18,
                ),
                filled: false,
                fillColor: Colors.transparent,
                hintText: 'Phone number',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.28),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRememberDeviceRow() {
    return InkWell(
      onTap: () {
        Haptics.selection();
        setState(() => _rememberDevice = !_rememberDevice);
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              height: 24,
              child: Checkbox(
                value: _rememberDevice,
                onChanged: (value) {
                  Haptics.selection();
                  setState(() => _rememberDevice = value ?? false);
                },
                activeColor: _accent,
                checkColor: Colors.black,
                side: BorderSide(color: Colors.white.withValues(alpha: 0.35)),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Remember this device for 90 days',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.72),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthField() {
    final bool focused = _authFocus.hasFocus;

    final TextStyle pinStyle = TextStyle(
      fontSize: 24,
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 10,
      fontFeatures: const [FontFeature.tabularFigures()],
    );

    final TextStyle passwordStyle = TextStyle(
      fontSize: 18,
      color: Colors.white,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.2,
    );

    return _GlassField(
      focused: focused,
      child: TextFormField(
        focusNode: _authFocus,
        controller: _pinController,
        style: (_hasPin && !_usePassword) ? pinStyle : passwordStyle,
        keyboardType: (_hasPin && !_usePassword)
            ? TextInputType.number
            : TextInputType.visiblePassword,
        cursorColor: Colors.white,
        obscureText: _obscureText,
        textAlign: (_hasPin && !_usePassword)
            ? TextAlign.center
            : TextAlign.start,
        textInputAction: TextInputAction.done,
        autofillHints: (_hasPin && !_usePassword)
            ? const []
            : const [AutofillHints.password],
        inputFormatters: (_hasPin && !_usePassword)
            ? [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ]
            : null,
        onFieldSubmitted: (_) => _handleAuthSubmit(),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 18,
          ),
          filled: false,
          fillColor: Colors.transparent,
          hintText: (_hasPin && !_usePassword) ? '••••••' : 'Password',
          hintStyle: TextStyle(
            color: Colors.white.withValues(alpha: 0.18),
            letterSpacing: (_hasPin && !_usePassword) ? 10 : -0.2,
            fontWeight: FontWeight.w600,
          ),
          suffixIcon: IconButton(
            splashRadius: 18,
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withValues(alpha: 0.35),
              size: 20,
            ),
            onPressed: () => setState(() => _obscureText = !_obscureText),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorSnack({Key? key}) {
    return ClipRRect(
      key: key,
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFFFF453A).withValues(alpha: 0.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 1),
                child: Icon(Icons.error_outline, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => setState(() => _errorMessage = null),
                child: const Padding(
                  padding: EdgeInsets.only(top: 1),
                  child: Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

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

/// Frosted field container (Apple-like restraint)
class _GlassField extends StatelessWidget {
  const _GlassField({required this.child, required this.focused});

  final Widget child;
  final bool focused;

  // Solid dark background - NO blur to avoid glow bleed-through
  static const Color _solidBg = DesignTokens.brandPrimary;
  static const Color _stroke = Color(0x33FFFFFF);
  static const Color _strokeFocused = DesignTokens.info;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: _solidBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: focused ? _strokeFocused : _stroke,
          width: focused ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _LoginFeatureRow extends StatelessWidget {
  const _LoginFeatureRow();

  static const _accent = DesignTokens.brandAccent;
  static const _stroke = Color(0x22FFFFFF);

  static const _items = [
    (Icons.point_of_sale_rounded, 'POS checkout'),
    (Icons.sync_rounded, 'Instant sync'),
    (Icons.brush_rounded, 'Soko Studio'),
    (Icons.wifi_off_rounded, 'Works offline'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _items
          .map(
            (item) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: _stroke),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(item.$1, size: 14, color: _accent),
                  const SizedBox(width: 6),
                  Text(
                    item.$2,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.7),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

/// Soft background glow blob
class _GlowBlob extends StatelessWidget {
  const _GlowBlob({required this.color, required this.size});
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.55),
            blurRadius: 120,
            spreadRadius: 30,
          ),
        ],
      ),
    );
  }
}

class _MainButton extends StatefulWidget {
  const _MainButton({
    required this.text,
    this.isLoading = false,
    required this.onTap,
  });

  final String text;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  State<_MainButton> createState() => _MainButtonState();
}

class _MainButtonState extends State<_MainButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool disabled = widget.isLoading;

    return GestureDetector(
      onTapDown: disabled ? null : (_) => setState(() => _pressed = true),
      onTapCancel: disabled ? null : () => setState(() => _pressed = false),
      onTap: disabled
          ? null
          : () {
              setState(() => _pressed = false);
              widget.onTap();
            },
      child: AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: _pressed ? 0.985 : 1.0,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 120),
          opacity: disabled ? 0.9 : 1.0,
          child: Container(
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: DesignTokens.brandAccent,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
