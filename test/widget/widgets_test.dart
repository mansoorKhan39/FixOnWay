import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/widgets/empty_state.dart';
import 'package:fixonway/core/widgets/photo_strip.dart';
import 'package:fixonway/core/utils/ui_helpers.dart';
import 'package:fixonway/core/widgets/star_row.dart';
import 'package:fixonway/core/widgets/status_chip.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/photo_attachment.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('StarRow shows the rating and reports taps', (tester) async {
    int tapped = 0;
    await tester.pumpWidget(
      host(StarRow(rating: 3, onChanged: (int v) => tapped = v)),
    );
    expect(find.byIcon(Icons.star), findsNWidgets(3));
    expect(find.byIcon(Icons.star_border), findsNWidgets(2));
    await tester.tap(find.byIcon(Icons.star_border).first);
    expect(tapped, 4);
  });

  testWidgets('StarRow without a callback is read-only', (tester) async {
    await tester.pumpWidget(host(const StarRow(rating: 5)));
    expect(find.byIcon(Icons.star), findsNWidgets(5));
    expect(find.byIcon(Icons.star_border), findsNothing);
  });

  testWidgets('StatusChip shows the status label', (tester) async {
    await tester.pumpWidget(
      host(const StatusChip(status: RequestStatus.onTheWay)),
    );
    expect(find.text(RequestStatus.onTheWay.label), findsOneWidget);
  });

  testWidgets('EmptyState shows its message', (tester) async {
    await tester.pumpWidget(
      host(const EmptyState(icon: Icons.inbox, message: 'Nothing here')),
    );
    expect(find.text('Nothing here'), findsOneWidget);
  });

  testWidgets('PhotoStrip counts demo photos', (tester) async {
    await tester.pumpWidget(
      host(
        const PhotoStrip(
          photos: <PhotoAttachment>[
            PhotoAttachment(name: 'a.jpg', sizeBytes: 10),
            PhotoAttachment(name: 'b.jpg', sizeBytes: 10),
          ],
        ),
      ),
    );
    expect(find.text('2 photo(s) attached'), findsOneWidget);
  });
}
