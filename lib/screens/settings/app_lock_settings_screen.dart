import 'package:flutter/material.dart';

import '../../services/app_lock_service.dart';
import '../../widgets/account_password_dialog.dart';

class AppLockSettingsScreen extends StatefulWidget {
  const AppLockSettingsScreen({super.key});

  @override
  State<AppLockSettingsScreen> createState() => _AppLockSettingsScreenState();
}

class _AppLockSettingsScreenState extends State<AppLockSettingsScreen> {
  static const _ink = Color(0xFF17213D);
  static const _muted = Color(0xFF8495B2);
  static const _accent = Color(0xFF5A4BFF);

  final AppLockService _service = AppLockService();
  bool _loading = true;
  bool _enabled = false;
  bool _biometricsEnabled = false;
  bool _biometricsAvailable = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      _service.isEnabled,
      _service.biometricsEnabled,
      _service.canUseBiometrics,
    ]);
    if (!mounted) return;
    setState(() {
      _enabled = results[0];
      _biometricsEnabled = results[1];
      _biometricsAvailable = results[2];
      _loading = false;
    });
  }

  Future<String?> _requestPin({required String title}) async {
    final formKey = GlobalKey<FormState>();
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    final pin = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: pinController,
                autofocus: true,
                obscureText: true,
                maxLength: 8,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: '4–8 digit PIN',
                  counterText: '',
                ),
                validator: (value) {
                  final pin = value ?? '';
                  if (pin.length < 4 ||
                      pin.length > 8 ||
                      int.tryParse(pin) == null) {
                    return 'Enter 4 to 8 digits';
                  }
                  return null;
                },
              ),
              TextFormField(
                controller: confirmController,
                obscureText: true,
                maxLength: 8,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Confirm PIN',
                  counterText: '',
                ),
                validator: (value) =>
                    value != pinController.text ? 'PINs do not match' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, pinController.text);
              }
            },
            child: const Text('Save PIN'),
          ),
        ],
      ),
    );
    pinController.dispose();
    confirmController.dispose();
    return pin;
  }

  Future<void> _setLockEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      if (enabled) {
        final pin = await _requestPin(title: 'Set app PIN');
        if (pin == null) return;
        await _service.enable(pin: pin);
        if (!mounted) return;
        setState(() {
          _enabled = true;
          _biometricsEnabled = false;
        });
        _showMessage(
          'App lock enabled. It will lock when Synora goes to the background.',
        );
      } else {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Turn off App Lock?'),
            content: const Text(
              'Your saved PIN and biometric preference will be removed from this device.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Keep lock'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Turn off'),
              ),
            ],
          ),
        );
        if (confirmed != true) return;
        await _service.disable();
        if (mounted) {
          setState(() {
            _enabled = false;
            _biometricsEnabled = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        _showMessage('Could not update App Lock: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePin() async {
    final pin = await _requestPin(title: 'Change app PIN');
    if (pin == null) return;
    try {
      await _service.enable(pin: pin);
      if (mounted) _showMessage('App PIN changed.');
    } catch (error) {
      if (mounted) _showMessage('Could not change PIN: $error');
    }
  }

  Future<void> _recoverPin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final verified = await AccountPasswordDialog.verify(context);
      if (!mounted || !verified) return;
      final pin = await AccountPasswordDialog.requestNewPin(
        context,
        title: 'Reset app PIN',
      );
      if (!mounted || pin == null) return;
      await _service.enable(pin: pin);
      if (mounted) {
        setState(() {
          _enabled = true;
          _biometricsEnabled = false;
        });
        _showMessage('App PIN reset.');
      }
    } catch (error) {
      if (mounted) _showMessage('Could not reset app PIN: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setBiometrics(bool enabled) async {
    try {
      await _service.setBiometricsEnabled(enabled);
      if (mounted) setState(() => _biometricsEnabled = enabled);
    } catch (error) {
      if (mounted) _showMessage(error.toString());
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'App Lock',
          style: TextStyle(color: _ink, fontWeight: FontWeight.w800),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0EFFF),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.shield_outlined, color: _accent),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your PIN is kept in secure device storage. Synora asks you to unlock after you reopen the app.',
                          style: TextStyle(color: _ink, height: 1.4),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _tile(
                  child: SwitchListTile.adaptive(
                    value: _enabled,
                    onChanged: _busy ? null : _setLockEnabled,
                    activeTrackColor: _accent,
                    title: const Text(
                      'App Lock',
                      style: TextStyle(
                        color: _ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      _enabled
                          ? 'PIN required when Synora returns to the foreground'
                          : 'Require your PIN whenever you reopen Synora',
                      style: const TextStyle(color: _muted, fontSize: 12),
                    ),
                  ),
                ),
                if (_enabled) ...[
                  const SizedBox(height: 8),
                  _tile(
                    child: ListTile(
                      leading: const Icon(
                        Icons.password_rounded,
                        color: _accent,
                      ),
                      title: const Text(
                        'Change PIN',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _muted,
                      ),
                      onTap: _busy ? null : _changePin,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _tile(
                    child: ListTile(
                      leading: const Icon(
                        Icons.lock_reset_rounded,
                        color: _accent,
                      ),
                      title: const Text(
                        'Forgot PIN?',
                        style: TextStyle(
                          color: _ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      subtitle: const Text(
                        'Verify your account password to set a new app PIN',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: _muted,
                      ),
                      onTap: _busy ? null : _recoverPin,
                    ),
                  ),
                  if (_biometricsAvailable) ...[
                    const SizedBox(height: 8),
                    _tile(
                      child: SwitchListTile.adaptive(
                        value: _biometricsEnabled,
                        onChanged: _busy ? null : _setBiometrics,
                        activeTrackColor: _accent,
                        secondary: const Icon(
                          Icons.fingerprint_rounded,
                          color: _accent,
                        ),
                        title: const Text(
                          'Fingerprint / Face unlock',
                          style: TextStyle(
                            color: _ink,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        subtitle: const Text(
                          'Use an enrolled biometric on this device; PIN remains available',
                          style: TextStyle(color: _muted, fontSize: 12),
                        ),
                      ),
                    ),
                  ] else
                    const Padding(
                      padding: EdgeInsets.fromLTRB(8, 12, 8, 0),
                      child: Text(
                        'No enrolled fingerprint or face authentication was detected on this device.',
                        style: TextStyle(color: _muted, fontSize: 12),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Widget _tile({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFE8EDF5)),
    ),
    child: child,
  );
}
