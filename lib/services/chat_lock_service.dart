import 'package:flutter_secure_storage/flutter_secure_storage.dart';

enum ChatLockKind { direct, group }

class ChatLockService {
  ChatLockService({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  String _key({
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
  }) {
    return 'synora_chat_lock_${kind.name}_${userId}_$conversationId';
  }

  Future<bool> isEnabled({
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
  }) async {
    final pin = await _storage.read(
      key: _key(userId: userId, conversationId: conversationId, kind: kind),
    );
    return pin?.isNotEmpty ?? false;
  }

  Future<void> enable({
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
    required String pin,
  }) async {
    if (pin.length < 4 || pin.length > 8 || int.tryParse(pin) == null) {
      throw ArgumentError('PIN must contain 4 to 8 digits.');
    }
    await _storage.write(
      key: _key(userId: userId, conversationId: conversationId, kind: kind),
      value: pin,
    );
  }

  Future<bool> verify({
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
    required String pin,
  }) async {
    final storedPin = await _storage.read(
      key: _key(userId: userId, conversationId: conversationId, kind: kind),
    );
    return storedPin == pin;
  }

  Future<void> disable({
    required String userId,
    required String conversationId,
    required ChatLockKind kind,
  }) async {
    await _storage.delete(
      key: _key(userId: userId, conversationId: conversationId, kind: kind),
    );
  }
}
