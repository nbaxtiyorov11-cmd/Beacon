import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

const trackingNotificationPauseAction = 'tracking_pause';
const trackingNotificationEndAction = 'tracking_end';

bool _trackingForegroundServiceEnabled = true;

void initializeTrackingForegroundService({bool enabled = true}) {
  _trackingForegroundServiceEnabled = enabled;
  if (!enabled || defaultTargetPlatform != TargetPlatform.android) return;

  FlutterForegroundTask.initCommunicationPort();
  FlutterForegroundTask.init(
    androidNotificationOptions: AndroidNotificationOptions(
      channelId: 'beacon_tracking',
      channelName: 'Beacon tracking',
      channelDescription: 'Live trip controls and movement metrics.',
      onlyAlertOnce: true,
    ),
    iosNotificationOptions: const IOSNotificationOptions(
      showNotification: false,
      playSound: false,
    ),
    foregroundTaskOptions: ForegroundTaskOptions(
      eventAction: ForegroundTaskEventAction.nothing(),
      allowWakeLock: true,
    ),
  );
}

@pragma('vm:entry-point')
void startTrackingForegroundTask() {
  FlutterForegroundTask.setTaskHandler(_TrackingTaskHandler());
}

class _TrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp) async {}

  @override
  void onNotificationButtonPressed(String id) {
    if (id != trackingNotificationPauseAction &&
        id != trackingNotificationEndAction) {
      return;
    }
    FlutterForegroundTask.sendDataToMain({
      'type': 'tracking_notification_action',
      'action': id,
    });
  }
}

abstract final class TrackingForegroundService {
  static bool get isSupported =>
      _trackingForegroundServiceEnabled &&
      defaultTargetPlatform == TargetPlatform.android;

  static Future<void> start() async {
    if (!isSupported) return;

    final permission = await FlutterForegroundTask.checkNotificationPermission();
    if (permission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }
    if (await FlutterForegroundTask.checkNotificationPermission() !=
        NotificationPermission.granted) {
      throw StateError('Allow notifications to use tracking controls.');
    }

    if (await FlutterForegroundTask.isRunningService) {
      await update(text: 'Preparing your trip…');
      return;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 4201,
      notificationTitle: 'Beacon tracking',
      notificationText: 'Preparing your trip…',
      notificationButtons: _buttons,
      callback: startTrackingForegroundTask,
    );
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Could not start tracking notification: $error');
    }
  }

  static Future<void> update({required String text}) async {
    if (!isSupported || !await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.updateService(
      notificationTitle: 'Beacon tracking',
      notificationText: text,
      notificationButtons: _buttons,
    );
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Could not update tracking notification: $error');
    }
  }

  static Future<void> stop() async {
    if (!isSupported || !await FlutterForegroundTask.isRunningService) return;
    final result = await FlutterForegroundTask.stopService();
    if (result case ServiceRequestFailure(:final error)) {
      throw StateError('Could not stop tracking notification: $error');
    }
  }

  static const _buttons = [
    NotificationButton(id: trackingNotificationPauseAction, text: 'Pause'),
    NotificationButton(id: trackingNotificationEndAction, text: 'End trip'),
  ];
}
