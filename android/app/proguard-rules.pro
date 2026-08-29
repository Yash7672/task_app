# PYLO Widget providers - must not be stripped by R8/ProGuard
-keep class com.example.task_app.PyloHomeWidgetProvider { *; }
-keep class com.example.task_app.PyloHabitsWidgetProvider { *; }
-keep class com.example.task_app.PyloProgressWidgetProvider { *; }
-keep class com.example.task_app.PyloQuickAddWidgetProvider { *; }
-keep class com.example.task_app.PyloFocusWidgetProvider { *; }
-keep class com.example.task_app.PyloChecklistWidgetProvider { *; }
-keep class com.example.task_app.PyloBirthdaysWidgetProvider { *; }
-keep class com.example.task_app.WidgetBootReceiver { *; }

# home_widget package
-keep class es.antonborri.home_widget.** { *; }

# Flutter generated plugin registrant
-keep class io.flutter.plugins.** { *; }
