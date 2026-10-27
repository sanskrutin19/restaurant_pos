import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../core/pos_theme.dart';
import '../providers.dart';

class LicenseActivationScreen extends ConsumerStatefulWidget {
  final String machineId;
  const LicenseActivationScreen({super.key, required this.machineId});

  @override
  ConsumerState<LicenseActivationScreen> createState() => _LicenseActivationScreenState();
}

class _LicenseActivationScreenState extends ConsumerState<LicenseActivationScreen> {
  final _keyController = TextEditingController();
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _handleActivate() async {
    final key = _keyController.text.trim();
    if (key.isEmpty) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final success = await ref.read(licenseProvider.notifier).activate(key);
    
    if (mounted) {
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Servezy Activated Successfully!'), backgroundColor: Colors.green),
        );
      } else {
        setState(() {
          _isLoading = false;
          _error = 'Invalid Activation Key. Please contact support.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Logo/Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: POSTheme.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.verified_user_rounded, color: POSTheme.primary, size: 48),
              ),
              const SizedBox(height: 24),
              
              Text(
                'Activate Servezy',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Please enter your product activation key.',
                style: GoogleFonts.inter(color: Colors.blueGrey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Machine ID Box
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Column(
                  children: [
                    Text(
                      'YOUR MACHINE ID',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1,
                        color: Colors.blueGrey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          widget.machineId,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF334155),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.copy_rounded, size: 18),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: widget.machineId));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('ID Copied to Clipboard')),
                            );
                          },
                          tooltip: 'Copy ID',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Key Input
              TextField(
                controller: _keyController,
                style: GoogleFonts.jetBrainsMono(fontSize: 18, letterSpacing: 2),
                decoration: InputDecoration(
                  hintText: 'XXXX-XXXX-XXXX-XXXX',
                  hintStyle: GoogleFonts.jetBrainsMono(color: Colors.black26, fontSize: 14, letterSpacing: 1),
                  labelText: 'Activation Key',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  prefixIcon: const Icon(Icons.key_rounded),
                ),
                onSubmitted: (_) => _handleActivate(),
              ),
              
              if (_error != null) ...[
                const SizedBox(height: 16),
                Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
              
              const SizedBox(height: 32),
              
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleActivate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: POSTheme.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('ACTIVATE PRODUCT', style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 1)),
                ),
              ),
              
              const SizedBox(height: 24),
              Text(
                'Don\'t have a key? Contact support@servezy.com',
                style: GoogleFonts.inter(fontSize: 12, color: Colors.blueGrey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
