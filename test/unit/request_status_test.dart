import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/models/enums/request_status.dart';

void main() {
  group('valid transitions', () {
    const List<List<RequestStatus>> valid = <List<RequestStatus>>[
      <RequestStatus>[RequestStatus.pending, RequestStatus.estimated],
      <RequestStatus>[RequestStatus.pending, RequestStatus.cancelled],
      <RequestStatus>[RequestStatus.pending, RequestStatus.expired],
      <RequestStatus>[RequestStatus.estimated, RequestStatus.accepted],
      <RequestStatus>[RequestStatus.accepted, RequestStatus.onTheWay],
      <RequestStatus>[RequestStatus.onTheWay, RequestStatus.arrived],
      <RequestStatus>[RequestStatus.arrived, RequestStatus.working],
      <RequestStatus>[RequestStatus.working, RequestStatus.completed],
      <RequestStatus>[RequestStatus.completed, RequestStatus.paid],
      <RequestStatus>[RequestStatus.completed, RequestStatus.disputed],
      <RequestStatus>[RequestStatus.disputed, RequestStatus.closed],
      <RequestStatus>[RequestStatus.paid, RequestStatus.closed],
    ];
    for (final List<RequestStatus> pair in valid) {
      test('${pair[0].name} -> ${pair[1].name}', () {
        expect(pair[0].canMoveTo(pair[1]), isTrue);
      });
    }
  });

  group('invalid transitions', () {
    const List<List<RequestStatus>> invalid = <List<RequestStatus>>[
      <RequestStatus>[RequestStatus.pending, RequestStatus.accepted],
      <RequestStatus>[RequestStatus.accepted, RequestStatus.working],
      <RequestStatus>[RequestStatus.working, RequestStatus.cancelled],
      <RequestStatus>[RequestStatus.completed, RequestStatus.pending],
      <RequestStatus>[RequestStatus.closed, RequestStatus.pending],
      <RequestStatus>[RequestStatus.cancelled, RequestStatus.accepted],
      <RequestStatus>[RequestStatus.expired, RequestStatus.estimated],
    ];
    for (final List<RequestStatus> pair in invalid) {
      test('${pair[0].name} -> ${pair[1].name}', () {
        expect(pair[0].canMoveTo(pair[1]), isFalse);
      });
    }
  });

  test('finished statuses', () {
    expect(RequestStatus.closed.isFinished, isTrue);
    expect(RequestStatus.cancelled.isFinished, isTrue);
    expect(RequestStatus.expired.isFinished, isTrue);
    expect(RequestStatus.working.isFinished, isFalse);
  });
}
