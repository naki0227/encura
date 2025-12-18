import 'package:home_widget/home_widget.dart';

class WidgetService {
  static const String appGroupId = 'group.com.example.encura'; // Replace with your actual App Group ID if using iOS App Groups
  static const String iOSWidgetName = 'StudyReelWidget';
  static const String androidWidgetName = 'HomeWidgetProvider';

  static Future<void> updateWidget({
    required String title,
    required String message,
  }) async {
    try {
      await HomeWidget.saveWidgetData<String>('title', title);
      await HomeWidget.saveWidgetData<String>('message', message);
      
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      print('Error updating widget: $e');
    }
  }
}
