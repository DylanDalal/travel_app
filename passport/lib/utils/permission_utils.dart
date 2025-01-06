import 'package:photo_manager/photo_manager.dart';

class PermissionUtils {
  /// Request photo library access using `photo_manager`
  static Future<bool> requestPhotoPermission() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    if (state == PermissionState.authorized) {
      print('Photo access granted');
      return true;
    } else if (state == PermissionState.limited) {
      print('Photo access granted with limitations');
      return true; // Limited access is still usable for certain operations
    } else {
      print('Photo access denied');
      return false;
    }
  }

  /// Handle denied permissions by opening settings
  static Future<void> openSettingsIfNeeded() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    if (state == PermissionState.denied ||
        state == PermissionState.restricted) {
      print('Opening app settings to allow photo access');
      await PhotoManager.openSetting();
    }
  }

  /// Check if photo access is granted
  static Future<bool> isPhotoAccessGranted() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend();
    return state == PermissionState.authorized ||
        state == PermissionState.limited;
  }
}
