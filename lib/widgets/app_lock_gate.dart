import 'package:flutter/material.dart';

import '../services/app_lock_service.dart';
import 'account_password_dialog.dart';

class AppLockGate extends StatefulWidget {
  final Widget child;

  const AppLockGate({super.key, required this.child});

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final AppLockService _lockService = AppLockService();
  bool _loading = true;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadLockState();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadLockState() async {
    final enabled = await _lockService.isEnabled;
    if (!mounted) return;
    setState(() {
      _locked = enabled;
      _loading = false;
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _lockOnBackground();
    } else if (state == AppLifecycleState.resumed) {
      _refreshOnResume();
    }
  }

  Future<void> _lockOnBackground() async {
    final enabled = await _lockService.isEnabled;
    if (!mounted || !enabled) return;
    setState(() => _locked = true);
  }

  Future<void> _refreshOnResume() async {
    final enabled = await _lockService.isEnabled;
    if (!mounted) return;
    setState(() {
      _locked = enabled && _locked;
      _loading = false;
    });
  }

  void _unlock() {
    if (mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (_loading)
          const _LockLoadingScreen()
        else if (_locked)
          AppLockScreen(service: _lockService, onUnlocked: _unlock),
      ],
    );
  }
}

class AppLockScreen extends StatefulWidget {
  final AppLockService service;
  final VoidCallback onUnlocked;

  const AppLockScreen({
    super.key,
    required this.service,
    required this.onUnlocked,
  });

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _checking = false;
  bool _showBiometrics = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _checkBiometricAvailability();
  }

  @override
  void dispose() {
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _checkBiometricAvailability() async {
    final available = await widget.service.canUseBiometrics;
    final enabled = await widget.service.biometricsEnabled;
    if (mounted) setState(() => _showBiometrics = available && enabled);
  }

  Future<void> _unlockWithPin() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    final valid = await widget.service.verifyPin(_pinController.text);
    if (!mounted) return;
    setState(() => _checking = false);
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Incorrect PIN. Try again.');
      _pinController.clear();
    }
  }

  Future<void> _unlockWithBiometrics() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    final valid = await widget.service.authenticateWithBiometrics();
    if (!mounted) return;
    setState(() => _checking = false);
    if (valid) {
      widget.onUnlocked();
    } else {
      setState(() => _error = 'Biometric verification did not complete.');
    }
  }

  Future<void> _recoverAppPin() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = '';
    });
    try {
      final verified = await AccountPasswordDialog.verify(context);
      if (!mounted) return;
      if (!verified) {
        setState(() => _checking = false);
        return;
      }
      final pin = await AccountPasswordDialog.requestNewPin(
        context,
        title: 'Reset app PIN',
      );
      if (!mounted) return;
      if (pin == null) {
        setState(() => _checking = false);
        return;
      }
      await widget.service.enable(pin: pin);
      if (mounted) widget.onUnlocked();
    } catch (error) {
      if (mounted) {
        setState(() {
          _checking = false;
          _error = 'Could not reset app PIN: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF5A4BFF);
    const ink = Color(0xFF17213D);
    return PopScope(
      canPop: false,
      child: Material(
        color: const Color(0xFFF8FAFC),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 68,
                      height: 68,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.lock_rounded,
                        color: accent,
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Synora is locked',
                      style: TextStyle(
                        color: ink,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 7),
                    const Text(
                      'Enter your app PIN to continue',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF8495B2)),
                    ),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _pinController,
                      autofocus: true,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.done,
                      maxLength: 8,
                      onSubmitted: (_) => _unlockWithPin(),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: ink,
                        fontSize: 22,
                        letterSpacing: 8,
                      ),
                      decoration: InputDecoration(
                        hintText: 'PIN',
                        counterText: '',
                        errorText: _error.isEmpty ? null : _error,
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5EAF2),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(
                            color: Color(0xFFE5EAF2),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: FilledButton(
                        onPressed: _checking ? null : _unlockWithPin,
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.white,
                        ),
                        child: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Unlock'),
                      ),
                    ),
                    if (_showBiometrics) ...[
                      const SizedBox(height: 8),
                      IconButton.filledTonal(
                        tooltip: 'Unlock with biometrics',
                        onPressed: _checking ? null : _unlockWithBiometrics,
                        icon: const Icon(Icons.fingerprint_rounded, size: 28),
                        style: IconButton.styleFrom(foregroundColor: accent),
                      ),
                    ],
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _checking ? null : _recoverAppPin,
                      child: const Text('Forgot app PIN?'),
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

class _LockLoadingScreen extends StatelessWidget {
  const _LockLoadingScreen();

  @override
  Widget build(BuildContext context) => const Material(
    color: Color(0xFFF8FAFC),
    child: Center(child: CircularProgressIndicator(color: Color(0xFF5A4BFF))),
  );
}
