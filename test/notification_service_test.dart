import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pg_prep_mobile/features/notifications/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unsupported notification targets do not block app startup', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    try {
      await expectLater(NotificationService.instance.init(), completes);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
