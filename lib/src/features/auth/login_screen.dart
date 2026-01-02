import 'dart:async';
import 'dart:ui';
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

class _LoginScreenState extends ConsumerState<LoginScreen> with TickerProviderStateMixin {
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
  bool _obscureText = true;

  // Animations
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  // Minimal “Apple-ish” palette
  static const Color _bg = Color(0xFF000000);
  static const Color _accent = Color(0xFF6C63FF);
  static const Color _surface = Color(0xFF0B0B10);
  static const Color _glass = Color(0xFF101018);
  static const Color _stroke = Color(0x22FFFFFF);
  static const Color _strokeStrong = Color(0x33FFFFFF);

  @override
  void initState() {
    super.initState();

    // UI chrome: dark, clean
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.black,
      systemNavigationBarIconBrightness: Brightness.light,
    ));

    _fadeController = AnimationController(duration: const Duration(milliseconds: 650), vsync: this);
    _fadeAnimation = CurvedAnimation(parent: _fadeController, curve: Curves.easeOutQuart);
    _fadeController.forward();

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
    super.dispose();
  }

  String get _normalizedPhone {
    String digits = _phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '${_selectedCountry.code}$digits';
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
    HapticFeedback.lightImpact();

    try {
      final auth = ref.read(authControllerProvider.notifier);
      final result = await auth.checkUserExistence(_normalizedPhone);

      if (!mounted) return;

      if (result['exists'] == true) {
        // User exists -> Determine auth method
        setState(() {
          _userName = result['name'];
          _hasPin = result['has_pin'] == true;
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
        context.go('/register', extra: {'phone': _phoneController.text.trim()});
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Connection error. Try again.');
    }
  }

  Future<void> _handleAuthSubmit() async {
    final input = _pinController.text;
    if (input.isEmpty) return;

    if (_hasPin && input.length < 5) {
      _showError('Invalid PIN');
      return;
    }

    if (!_hasPin && input.length < 3) {
      _showError('Invalid Password');
      return;
    }

    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    try {
      final auth = ref.read(authControllerProvider.notifier);

      if (_hasPin) {
        // Login with PIN
        await auth.loginWithQuickPin(
          phone: _normalizedPhone,
          pin: input,
        );
      } else {
        // Login with Password
        await auth.login(
          emailOrPhone: _normalizedPhone,
          password: input,
        );
      }

      if (!mounted) return;

      final state = ref.read(authControllerProvider);
      if (state.status == AuthStatus.authenticated) {
        HapticFeedback.mediumImpact();
        context.go('/home/checkout');
      } else {
        setState(() => _isLoading = false);
        _showError(state.message ?? 'Authentication failed');
        _pinController.clear();
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showError('Login failed');
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
    setState(() => _errorMessage = message);
    HapticFeedback.heavyImpact();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _errorMessage = null);
    });
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
                  colors: [
                    _bg,
                    Color(0xFF05050A),
                    _bg,
                  ],
                ),
              ),
            ),

            // Accent glow (soft, minimal)
            Positioned(
              top: -140,
              right: -120,
              child: _GlowBlob(color: _accent.withOpacity(0.16), size: 420),
            ),
            Positioned(
              bottom: -160,
              left: -130,
              child: _GlowBlob(color: Colors.white.withOpacity(0.06), size: 520),
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
                          children: [
                            _buildPhoneStep(),
                            _buildAuthStep(),
                          ],
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
                    color: _surface.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _stroke),
                  ),
                  child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 22),
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
                  color: Colors.white.withOpacity(0.9),
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
              'Welcome',
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 42,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.2,
                height: 1.05,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Enter your phone number to continue.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 44),
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
              style: TextStyle(color: Colors.white.withOpacity(0.35), fontSize: 13),
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
                    Icon(Icons.arrow_back, color: Colors.white.withOpacity(0.55), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _phoneController.text,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.55),
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
              _userName != null ? 'Hello, $_userName' : (_hasPin ? 'Enter PIN' : 'Password'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.95),
                fontSize: 34,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.9,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _hasPin ? 'Enter your 6-digit access PIN.' : 'Enter your password to login.',
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 16,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 44),
            _buildAuthField(),
            const SizedBox(height: 28),
            _MainButton(
              text: _hasPin ? 'Unlock' : 'Login',
              isLoading: _isLoading,
              onTap: _handleAuthSubmit,
            ),
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
            borderRadius: const BorderRadius.horizontal(left: Radius.circular(22)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              child: Row(
                children: [
                  Text(_selectedCountry.flag, style: const TextStyle(fontSize: 20)),
                  const SizedBox(width: 8),
                  Icon(Icons.keyboard_arrow_down, size: 16, color: Colors.white.withOpacity(0.55)),
                ],
              ),
            ),
          ),
          Container(width: 1, height: 26, color: Colors.white.withOpacity(0.10)),
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
                LengthLimitingTextInputFormatter(10),
              ],
              onFieldSubmitted: (_) => _handlePhoneSubmit(),
              decoration: InputDecoration(
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
                filled: false,
                fillColor: Colors.transparent,
                hintText: 'Phone number',
                hintStyle: TextStyle(
                  color: Colors.white.withOpacity(0.28),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
        ],
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
        style: _hasPin ? pinStyle : passwordStyle,
        keyboardType: _hasPin ? TextInputType.number : TextInputType.visiblePassword,
        cursorColor: Colors.white,
        obscureText: _obscureText,
        textAlign: _hasPin ? TextAlign.center : TextAlign.start,
        textInputAction: TextInputAction.done,
        autofillHints: _hasPin ? const [] : const [AutofillHints.password],
        inputFormatters: _hasPin
            ? [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)]
            : null,
        onFieldSubmitted: (_) => _handleAuthSubmit(),
        decoration: InputDecoration(
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
          filled: false,
          fillColor: Colors.transparent,
          hintText: _hasPin ? '••••••' : 'Password',
          hintStyle: TextStyle(
            color: Colors.white.withOpacity(0.18),
            letterSpacing: _hasPin ? 10 : -0.2,
            fontWeight: FontWeight.w600,
          ),
          suffixIcon: IconButton(
            splashRadius: 18,
            icon: Icon(
              _obscureText ? Icons.visibility_off : Icons.visibility,
              color: Colors.white.withOpacity(0.35),
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
            color: const Color(0xFFFF453A).withOpacity(0.86),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showCountryPicker() async {
    final selected = await showCountryPickerBottomSheet(context, _selectedCountry);
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
  static const Color _solidBg = Color(0xFF1A1A24);
  static const Color _stroke = Color(0x33FFFFFF);
  static const Color _strokeFocused = Color(0xFF6C63FF);

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
            color: Colors.black.withOpacity(0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
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
          BoxShadow(color: color.withOpacity(0.55), blurRadius: 120, spreadRadius: 30),
        ],
      ),
    );
  }
}

class _MainButton extends StatefulWidget {
  const _MainButton({required this.text, this.isLoading = false, required this.onTap});

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
      onTapUp: disabled
          ? null
          : (_) {
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
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.white.withOpacity(0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.35),
                  blurRadius: 24,
                  offset: const Offset(0, 16),
                ),
              ],
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                  )
                : Text(
                    widget.text,
                    style: const TextStyle(
                      color: Colors.black,
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
