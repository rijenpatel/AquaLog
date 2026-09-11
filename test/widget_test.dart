import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:aqualog/app/app.dart';
import 'package:aqualog/core/database/app_database.dart';
import 'package:aqualog/core/providers/database_provider.dart';
import 'package:aqualog/core/providers/settings_provider.dart';
import 'package:aqualog/core/services/demo_data_service.dart';

void main() {
  testWidgets('AquaLogApp renders successfully with tabs and header', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase(NativeDatabase.memory());
    await db.saveUserProfile('Farmer John');
    await DemoDataService(db).loadDemoData();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          appDatabaseProvider.overrideWithValue(db),
        ],
        child: const AquaLogApp(),
      ),
    );

    // Initial pump & settle
    await tester.pumpAndSettle();

    // Verify app name or header exists
    expect(find.text('AquaLog'), findsWidgets);
    expect(find.text('Overview'), findsWidgets);
    expect(find.text('Manage'), findsWidgets);

    await db.close();
  });
}
