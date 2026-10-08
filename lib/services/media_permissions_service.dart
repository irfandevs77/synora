import 'package:permission_handler/permission_handler.dart';

class MediaPermissionsService {
  const MediaPermissionsService._();

  static Future<bool> requestGallery() async {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }

  static Future<bool> requestCamera() async {
    final status = await Permission.camera.request();
    return status.isGranted;
  }

  static Future<bool> requestMicrophone() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  static Future<bool> requestFiles() async {
    final status = await Permission.storage.request();
    return status.isGranted;
  }
}
