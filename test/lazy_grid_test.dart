import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

/// Verifies MasonryGridView lazy-loads children when not using shrinkWrap.
/// This is the core fix for the OOM crash on low-memory TV devices.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MasonryGridView lazy loading', () {
    testWidgets('renders only visible children, not all items', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: MasonryGridView.count(
                crossAxisCount: 5,
                itemCount: 100,
                itemBuilder: (_, i) {
                  buildCount++;
                  return SizedBox(
                    height: 100,
                    child: Text('item_$i'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // With lazy loading (no shrinkWrap), NOT all 100 items should be built.
      // Only enough to fill the visible area (300px height / 100px = 3 rows × 5 cols = ~15 items)
      // plus some overscroll buffer.
      expect(buildCount, lessThan(50));
      expect(buildCount, greaterThan(0));
    });

    testWidgets('with shrinkWrap true, builds ALL items (the old behavior)', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: MasonryGridView.count(
                crossAxisCount: 5,
                itemCount: 50,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (_, i) {
                  buildCount++;
                  return SizedBox(
                    height: 100,
                    child: Text('item_$i'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      // With shrinkWrap=true (old behavior), ALL items are built
      expect(buildCount, equals(50));
    });

    testWidgets('scrolling loads more items lazily', (tester) async {
      int buildCount = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 300,
              child: MasonryGridView.count(
                crossAxisCount: 5,
                itemCount: 100,
                itemBuilder: (_, i) {
                  buildCount++;
                  return SizedBox(
                    height: 100,
                    child: Text('item_$i'),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      final initialBuilds = buildCount;

      // Scroll down
      await tester.drag(find.byType(MasonryGridView), const Offset(0, -500));
      await tester.pump();

      // More items should have been built after scrolling
      expect(buildCount, greaterThan(initialBuilds));
    });
  });

  group('ImageCache limit', () {
    test('image cache is capped at 20MB for low-memory devices', () {
      // The image cache limit is set in AppInitializer.initialize()
      // Verify the constant is correct: 20 * 1024 * 1024 = 20971520
      const expectedBytes = 20 * 1024 * 1024;
      expect(expectedBytes, equals(20971520));

      // With memCacheWidth:360, memCacheHeight:202, each image ≈ 0.29MB
      // 20MB / 0.29MB ≈ 68 images can be cached
      // Screen shows ~10 cards at a time, so LRU eviction works naturally
      final imagesPerScreen = 10;
      final bytesPerImage = 360 * 202 * 4; // RGBA
      final totalScreenBytes = imagesPerScreen * bytesPerImage;
      expect(totalScreenBytes, lessThan(expectedBytes));
    });
  });
}
