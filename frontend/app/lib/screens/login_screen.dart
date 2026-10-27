import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/pos_theme.dart';
import '../providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _rememberMe = false;
  String? _errorMessage;
  
  late AnimationController _leftAnimController;
  late AnimationController _rightAnimController;
  late AnimationController _backgroundController;
  late Animation<Offset> _leftSlideAnim;
  late Animation<Offset> _rightSlideAnim;
  late Animation<double> _fadeAnim;

  // Staggered Form Animations
  late List<Animation<double>> _formElementAnims;
  late List<Animation<double>> _leftElementAnims;

  @override
  void initState() {
    super.initState();
    _leftAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _rightAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _backgroundController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();

    _fadeAnim = CurvedAnimation(
      parent: _leftAnimController,
      curve: Curves.easeIn,
    );

    _leftSlideAnim = Tween<Offset>(
      begin: const Offset(-0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _leftAnimController,
      curve: Curves.easeOutCubic,
    ));

    _rightSlideAnim = Tween<Offset>(
      begin: const Offset(0.05, 0),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _rightAnimController,
      curve: Curves.easeOutCubic,
    ));

    // Create 8 staggered animations for form elements
    _formElementAnims = List.generate(8, (index) {
      final start = 0.4 + (index * 0.08); // Starts after left panel begins
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _rightAnimController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    // Create 13 staggered animations for left panel elements (Hero + 8 features + Footer)
    _leftElementAnims = List.generate(13, (index) {
      final start = 0.05 + (index * 0.06); // Faster, smoother wave
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _leftAnimController,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _leftAnimController.forward();
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) _rightAnimController.forward();
    });
  }

  @override
  void dispose() {
    _leftAnimController.dispose();
    _rightAnimController.dispose();
    _backgroundController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Please enter username and password');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await ref.read(authProvider.notifier).login(username, password);
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed. Please check your credentials.';
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;
          
          if (isMobile) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildMobileHeader(),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
                    child: _buildLoginForm(fullWidth: true),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Left Side - Information Panel (50%)
              Expanded(
                flex: 1,
                child: SlideTransition(
                  position: _leftSlideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: _buildInfoPanel(),
                  ),
                ),
              ),
              
              // Right Side - Login Form (50%)
              Expanded(
                flex: 1,
                child: SlideTransition(
                  position: _rightSlideAnim,
                  child: FadeTransition(
                    opacity: _fadeAnim,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(40),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: _buildLoginForm(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildMobileHeader() {
    return Container(
      width: double.infinity,
      height: 280,
      child: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _backgroundController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _MeshGradientPainter(_backgroundController.value),
                );
              },
            ),
          ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _staggerLeftStep(0, 
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Colors.white, size: 60),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _staggerLeftStep(2,
                  Text(
                    'The Future of Dining is Here',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: Colors.white.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoPanel() {
    return Stack(
      children: [
        // Animated Mesh Gradient Background
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _backgroundController,
            builder: (context, child) {
              return CustomPaint(
                painter: _MeshGradientPainter(_backgroundController.value),
              );
            },
          ),
        ),
        
        // Content
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Logo & Title
              _staggerLeftStep(0, 
                Row(
                  children: [
                    Image.asset(
                      'assets/images/logo.png',
                      width: 50,
                      height: 50,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.restaurant, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              
              _staggerLeftStep(1,
                Text(
                  'The Power of Modern\nRestaurant Management',
                  style: GoogleFonts.outfit(
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.05,
                    letterSpacing: -1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _staggerLeftStep(2,
                Text(
                  'Streamline your operations with our enterprise-grade\nall-in-one solution designed for scale.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: Colors.white.withOpacity(0.75),
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // 8 Feature Grid
              Expanded(
                flex: 12,
                child: Column(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildFeatureItem(3, Icons.sync_rounded, 'Real-time Sync', 'Instant synchronization across all terminals and mobile devices.')),
                          const SizedBox(width: 32),
                          Expanded(child: _buildFeatureItem(4, Icons.analytics_rounded, 'Advanced Analytics', 'Multi-unit reporting and AI-powered sales forecasting.')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildFeatureItem(5, Icons.security_rounded, 'Enterprise Security', 'Advanced encryption and role-based access controls for data safety.')),
                          const SizedBox(width: 32),
                          Expanded(child: _buildFeatureItem(6, Icons.wifi_off_rounded, 'Offline-First', 'Your restaurant never stops, even if the internet does.')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildFeatureItem(7, Icons.layers_rounded, 'Interactive Floor', 'Visual table mapping with real-time status and timers.')),
                          const SizedBox(width: 32),
                          Expanded(child: _buildFeatureItem(8, Icons.kitchen_rounded, 'Smart Kitchen', 'Chef-optimized order routing to reduce ticket times.')),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Expanded(
                      child: Row(
                        children: [
                          Expanded(child: _buildFeatureItem(9, Icons.diamond_rounded, 'Loyalty & Rewards', 'Built-in CRM to drive repeat business and engagement.')),
                          const SizedBox(width: 32),
                          Expanded(child: _buildFeatureItem(10, Icons.qr_code_scanner_rounded, 'QR Self-Service', 'Empower guests to order and pay directly from their table.')),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const Spacer(),
              
              _staggerLeftStep(11,
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white.withOpacity(0.1)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.verified_user_rounded, color: Color(0xFF60A5FA), size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Trusted by 500+ Restaurants Globally',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureItem(int index, IconData icon, String title, String description) {
    return _staggerLeftStep(index, 
      _HoverScaleWidget(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.6),
                      height: 1.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _staggerLeftStep(int index, Widget child) {
    return AnimatedBuilder(
      animation: _leftElementAnims[index],
      builder: (context, child) {
        return Opacity(
          opacity: _leftElementAnims[index].value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _leftElementAnims[index].value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildLoginForm({bool fullWidth = false}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: fullWidth ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        _staggerStep(0, 
          fullWidth ? const SizedBox.shrink() : const Icon(Icons.restaurant, color: Color(0xFF3B82F6), size: 48),
        ),
        if (!fullWidth) const SizedBox(height: 32),
        
        _staggerStep(1,
          Text(
            'Welcome back',
            style: GoogleFonts.outfit(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
              letterSpacing: -0.5,
            ),
          ),
        ),
        const SizedBox(height: 8),
        _staggerStep(2,
          Text(
            'Sign in to manage your restaurant',
            style: GoogleFonts.inter(
              fontSize: 17,
              color: Colors.black45,
            ),
          ),
        ),
        const SizedBox(height: 48),

        // Error
        if (_errorMessage != null) 
          _staggerStep(3,
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (_errorMessage != null) const SizedBox(height: 24),

        // Username
        _staggerStep(3, _buildInputLabel('Username')),
        const SizedBox(height: 8),
        _staggerStep(3,
          _buildTextField(
            controller: _usernameController,
            hint: 'Enter your username',
            icon: Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 24),

        // Password
        _staggerStep(4, _buildInputLabel('Password')),
        const SizedBox(height: 8),
        _staggerStep(4,
          _buildTextField(
            controller: _passwordController,
            hint: 'Enter your password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            onSubmitted: (_) => _handleLogin(),
          ),
        ),
        const SizedBox(height: 16),

        // Remember Me & Forgot
        _staggerStep(5,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                   SizedBox(
                    width: 24,
                    height: 24,
                    child: Checkbox(
                      value: _rememberMe,
                      onChanged: (val) => setState(() => _rememberMe = val ?? false),
                      activeColor: const Color(0xFF3B82F6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Remember me',
                    style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => _showForgotPasswordDialog(context),
                child: Text(
                  'Forgot Password?',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Login Button
        _staggerStep(6,
          Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF3B82F6).withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3),
                    )
                  : Text(
                      'SIGN IN',
                      style: GoogleFonts.inter(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 2,
                      ),
                    ),
            ),
          ),
        ),
        
        const SizedBox(height: 48),
        _staggerStep(7,
          Center(
            child: Text(
              '© 2026 Servezy POS • v1.0.0',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: Colors.black26,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _staggerStep(int index, Widget child) {
    return AnimatedBuilder(
      animation: _formElementAnims[index],
      builder: (context, child) {
        return Opacity(
          opacity: _formElementAnims[index].value,
          child: Transform.translate(
            offset: Offset(0, 30 * (1 - _formElementAnims[index].value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      onSubmitted: onSubmitted,
      style: GoogleFonts.inter(color: const Color(0xFF1E293B)),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.black38, size: 22),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 2),
        ),
      ),
    );
  }

  void _showForgotPasswordDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ForgotPasswordDialog(),
    );
  }
}

class ForgotPasswordDialog extends ConsumerStatefulWidget {
  const ForgotPasswordDialog({super.key});

  @override
  ConsumerState<ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends ConsumerState<ForgotPasswordDialog> {
  final _usernameController = TextEditingController();
  final _codeController = TextEditingController();
  final _newPasswordController = TextEditingController();
  int _step = 1; // 1: Request Code, 2: Reset Password
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _usernameController.dispose();
    _codeController.dispose();
    _newPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleRequestCode() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.forgotPassword(username);
      setState(() => _step = 2);
    } catch (e) {
      setState(() => _error = 'User not found or server error.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleResetPassword() async {
    final username = _usernameController.text.trim();
    final code = _codeController.text.trim();
    final newPass = _newPasswordController.text;

    if (code.isEmpty || newPass.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final apiClient = ref.read(apiClientProvider);
      await apiClient.resetPassword(username, code, newPass);
      
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Password reset successfully! Log in with your new password.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _error = 'Invalid code or password reset failed.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _step == 1 ? 'Reset Password' : 'Verify Code',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E293B),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  splashRadius: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1 
                ? 'Enter your username to receive a reset code.' 
                : 'Enter the 6-digit code from the server console and your new password.',
              style: GoogleFonts.inter(fontSize: 14, color: Colors.black54),
            ),
            const SizedBox(height: 24),

            if (_error != null) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.inter(color: Colors.red, fontSize: 13),
                ),
              ),
              const SizedBox(height: 16),
            ],

            if (_step == 1) ...[
              _buildInputLabel('Username'),
              const SizedBox(height: 8),
              _buildDialogTextField(_usernameController, 'Enter username', Icons.person_outline),
              const SizedBox(height: 32),
              _buildPrimaryButton('SEND RESET CODE', _handleRequestCode),
            ] else ...[
              _buildInputLabel('Reset Code'),
              const SizedBox(height: 8),
              _buildDialogTextField(_codeController, '6-digit code', Icons.lock_clock_outlined),
              const SizedBox(height: 16),
              _buildInputLabel('New Password'),
              const SizedBox(height: 8),
              _buildDialogTextField(_newPasswordController, 'Enter new password', Icons.lock_outline, isPassword: true),
              const SizedBox(height: 32),
              _buildPrimaryButton('RESET PASSWORD', _handleResetPassword),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) {
    return Text(
      label,
      style: GoogleFonts.inter(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF475569),
      ),
    );
  }

  Widget _buildDialogTextField(TextEditingController controller, String hint, IconData icon, {bool isPassword = false}) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      style: GoogleFonts.inter(fontSize: 15),
      decoration: InputDecoration(
        prefixIcon: Icon(icon, size: 20, color: Colors.black38),
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.black26, fontSize: 14),
        filled: true,
        fillColor: const Color(0xFFF8FAFC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }

  Widget _buildPrimaryButton(String label, VoidCallback onPressed) {
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: ElevatedButton(
        onPressed: _isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
        child: _isLoading 
          ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
          : Text(label, style: GoogleFonts.inter(fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 0.5)),
      ),
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double animationValue;
  _MeshGradientPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    
    // Base gradient
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [const Color(0xFF1E3A8A), const Color(0xFF1E40AF), const Color(0xFF3B82F6)],
    ).createShader(rect);
    
    canvas.drawRect(rect, Paint()..shader = baseGradient);

    // Decorative moving circles (Mesh effect)
    final paint = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 120);
    
    void drawCircle(Offset center, double radius, Color color, double opacity) {
      canvas.drawCircle(center, radius, paint..color = color.withOpacity(opacity));
    }

    // Smoother, more overlapping movement
    final double x1 = size.width * (0.1 + 0.15 * (1 + sin(animationValue * 0.5 * 6.28)));
    final double y1 = size.height * (0.2 + 0.15 * (1 + cos(animationValue * 0.4 * 6.28)));
    drawCircle(Offset(x1, y1), 400, const Color(0xFF4F46E5), 0.25);

    final double x2 = size.width * (0.9 - 0.2 * (1 + sin(animationValue * 0.3 * 6.28)));
    final double y2 = size.height * (0.8 - 0.2 * (1 + cos(animationValue * 0.5 * 6.28)));
    drawCircle(Offset(x2, y2), 350, const Color(0xFF3B82F6), 0.2);

    final double x3 = size.width * (0.4 + 0.2 * (1 + cos(animationValue * 0.2 * 6.28)));
    final double y3 = size.height * (0.6 + 0.2 * (1 + sin(animationValue * 0.3 * 6.28)));
    drawCircle(Offset(x3, y3), 300, const Color(0xFF1E40AF), 0.3);

    final double x4 = size.width * (0.7 + 0.1 * sin(animationValue * 0.8 * 6.28));
    final double y4 = size.height * (0.3 + 0.1 * cos(animationValue * 0.7 * 6.28));
    drawCircle(Offset(x4, y4), 200, const Color(0xFF6366F1), 0.15);
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter oldDelegate) => true;
}

class _HoverScaleWidget extends StatefulWidget {
  final Widget child;
  const _HoverScaleWidget({required this.child});

  @override
  State<_HoverScaleWidget> createState() => _HoverScaleWidgetState();
}

class _HoverScaleWidgetState extends State<_HoverScaleWidget> {
  bool _isHovered = false;

  void _handleHoverChange(bool isHovered) {
    if (_isHovered == isHovered) return;
    
    // Using a microtask helps prevent the "Failed assertion: !_debugDuringDeviceUpdate" error
    // which can occur when setState triggers a rebuild that modifies the mouse tracker state
    // during a mouse event callback.
    Future.microtask(() {
      if (mounted && _isHovered != isHovered) {
        setState(() => _isHovered = isHovered);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => _handleHoverChange(true),
      onExit: (_) => _handleHoverChange(false),
      child: AnimatedScale(
        scale: _isHovered ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _isHovered ? Colors.white.withOpacity(0.1) : Colors.transparent,
            borderRadius: BorderRadius.circular(16),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}
