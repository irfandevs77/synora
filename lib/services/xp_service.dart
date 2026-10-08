import 'package:cloud_functions/cloud_functions.dart';

class XpService {
  final FirebaseFunctions _functions;

  XpService({FirebaseFunctions? functions})
      : _functions = functions ?? FirebaseFunctions.instance;

  Future<Map<String, dynamic>> completeSignup({
    required Map<String, dynamic> profile,
    String? referralId,
  }) async {
    final result = await _functions.httpsCallable('completeSignup').call({
      'profile': profile,
      if (referralId != null && referralId.trim().isNotEmpty)
        'referralId': referralId.trim(),
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> recordUsage(int seconds) async {
    final result = await _functions.httpsCallable('recordUsage').call({
      'seconds': seconds,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> grantAdXp(String adId) async {
    final result = await _functions.httpsCallable('grantAdXp').call({
      'adId': adId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  Future<Map<String, dynamic>> transferXp({
    required String receiverId,
    required int amount,
    required String transferId,
  }) async {
    final result = await _functions.httpsCallable('transferXp').call({
      'receiverId': receiverId,
      'amount': amount,
      'transferId': transferId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}