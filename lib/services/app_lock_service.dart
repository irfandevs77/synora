import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class AppLockService {
  AppLockService({FlutterSecureStorage? storage, LocalAuthentication? auth})
    : _storage = storage ?? const FlutterSecureStorage(),
      _auth = auth ?? LocalAuthentication();

  static const _enabledKey = 'synora_app_lock_enabled';
  static const _pinKey = 'synora_app_lock_pin';
  static const _biometricKey = 'synora_app_lock_biometrics';

  final FlutterSecureStorage _storage;
  final LocalAuthentication _auth;

  Future<bool> get isEnabled async =>
      await _storage.read(key: _enabledKey) == 'true' && await hasPin;

  Future<bool> get hasPin async =>
      (await _storage.read(key: _pinKey))?.isNotEmpty ?? false;

  Future<bool> get biometricsEnabled async =>
      await _storage.read(key: _biometricKey) == 'true';

  Future<bool> get canUseBiometrics async {
    try {
      return await _auth.isDeviceSupported() &&
          (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> enable({required String pin}) async {
    if (pin.length < 4 || pin.length > 8 || int.tryParse(pin) == null) {
      throw ArgumentError('PIN must contain 4 to 8 digits.');
    }
    await _storage.write(key: _pinKey, value: pin);
    await _storage.write(key: _biometricKey, value: 'false');
    await _storage.write(key: _enabledKey, value: 'true');
  }

  Future<void> setBiometricsEnabled(bool enabled) async {
    if (enabled && !await canUseBiometrics) {
      throw StateError('No enrolled biometrics are available on this device.');
    }
    await _storage.write(key: _biometricKey, value: enabled ? 'true' : 'false');
  }

  Future<bool> verifyPin(String pin) async =>
      (await _storage.read(key: _pinKey)) == pin;

  Future<bool> authenticateWithBiometrics() async {
    if (!await biometricsEnabled || !await canUseBiometrics) return false;
    try {
      return await _auth.authenticate(
        localizedReason: 'Unlock Synora',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  Future<void> disable() async {
    await _storage.delete(key: _enabledKey);
    await _storage.delete(key: _pinKey);
    await _storage.delete(key: _biometricKey);
  }
}