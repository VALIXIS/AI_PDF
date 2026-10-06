import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pdf_ai_toolkit/services/ad_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AdService adService;

  setUp(() {
    adService = AdService();
    adService.clearAllUnlocks();
  });

  tearDown(() {
    adService.clearAllUnlocks();
  });

  group('AdService Unit Tests', () {
    test('Singleton instance maintains consistent state', () {
      final instance1 = AdService();
      final instance2 = AdService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('Features are initially locked', () {
      expect(adService.isFeatureUnlocked(UnlockFeature.vectorExport), isFalse);
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isFalse);
      expect(adService.getRemainingMinutes(UnlockFeature.vectorExport), equals(0));
      expect(adService.getRemainingMinutes(UnlockFeature.aiSummaries), equals(0));
    });

    test('grantUnlock activates feature token and calculates remaining minutes', () {
      adService.grantUnlock(UnlockFeature.vectorExport, duration: const Duration(minutes: 60));

      expect(adService.isFeatureUnlocked(UnlockFeature.vectorExport), isTrue);
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isFalse);
      expect(adService.getRemainingMinutes(UnlockFeature.vectorExport), greaterThanOrEqualTo(59));

      // Grant AI summaries
      adService.grantUnlock(UnlockFeature.aiSummaries, duration: const Duration(minutes: 30));
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isTrue);
      expect(adService.getRemainingMinutes(UnlockFeature.aiSummaries), greaterThanOrEqualTo(29));
    });

    test('revokeUnlock and clearAllUnlocks reset active tokens', () {
      adService.grantUnlock(UnlockFeature.vectorExport);
      adService.grantUnlock(UnlockFeature.aiSummaries);

      expect(adService.isFeatureUnlocked(UnlockFeature.vectorExport), isTrue);
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isTrue);

      adService.revokeUnlock(UnlockFeature.vectorExport);
      expect(adService.isFeatureUnlocked(UnlockFeature.vectorExport), isFalse);
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isTrue);

      adService.clearAllUnlocks();
      expect(adService.isFeatureUnlocked(UnlockFeature.aiSummaries), isFalse);
    });

    test('preloadRewardedVideoAd prepares ad asset state', () async {
      await adService.preloadRewardedVideoAd();
      expect(adService.isAdReady, isTrue);
    });
  });

  group('Ad UI Component Widget Tests', () {
    testWidgets('WatchAdUnlockButton renders locked state and transitions to unlocked state',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WatchAdUnlockButton(
                feature: UnlockFeature.vectorExport,
                onUnlocked: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Initial locked button
      expect(find.text('Watch Ad to Unlock Free'), findsOneWidget);
      expect(find.byIcon(Icons.play_circle_filled_rounded), findsOneWidget);

      // Manually grant unlock and rebuild
      adService.grantUnlock(UnlockFeature.vectorExport, duration: const Duration(minutes: 45));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: WatchAdUnlockButton(
                feature: UnlockFeature.vectorExport,
                onUnlocked: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Unlocked'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    });
  });
}
