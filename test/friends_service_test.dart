import 'package:flutter_test/flutter_test.dart';
import 'package:synora/services/friends_service.dart';

void main() {
  group('FriendsService document IDs', () {
    test('creates the same ID regardless of friend order', () {
      expect(FriendsService.getDeterministicDocId('user-a', 'user-b'), 'user-a_user-b');
      expect(FriendsService.getDeterministicDocId('user-b', 'user-a'), 'user-a_user-b');
    });

    test('creates a stable ID for equal user IDs', () {
      expect(FriendsService.getDeterministicDocId('user-a', 'user-a'), 'user-a_user-a');
    });
  });
}
