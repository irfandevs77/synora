import 'package:flutter_test/flutter_test.dart';
import 'package:synora/controllers/chat_controllers.dart';

void main() {
  group('ChatController attachment helpers', () {
    test('returns a readable label for image attachments', () {
      final controller = ChatController();

      expect(controller.attachmentLabelForType('image'), 'sent a photo');
      expect(controller.attachmentLabelForType('video'), 'sent a video');
      expect(controller.attachmentLabelForType('audio'), 'sent an audio message');
    });
  });
}
