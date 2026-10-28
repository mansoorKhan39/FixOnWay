import 'package:flutter_test/flutter_test.dart';
import 'package:fixonway/core/constants/app_constants.dart';
import 'package:fixonway/core/errors/app_exception.dart';
import 'package:fixonway/models/app_notification.dart';
import 'package:fixonway/models/app_user.dart';
import 'package:fixonway/models/chat_message.dart';
import 'package:fixonway/models/enums/complaint_category.dart';
import 'package:fixonway/models/enums/payment_method.dart';
import 'package:fixonway/models/enums/problem_type.dart';
import 'package:fixonway/models/enums/request_status.dart';
import 'package:fixonway/models/enums/user_role.dart';
import 'package:fixonway/models/enums/vehicle_type.dart';
import 'package:fixonway/models/estimate.dart';
import 'package:fixonway/models/lat_lng.dart';
import 'package:fixonway/models/mechanic_profile.dart';
import 'package:fixonway/models/review.dart';
import 'package:fixonway/models/service_request.dart';
import 'package:fixonway/models/vehicle.dart';
import 'package:fixonway/repositories/mock_chat_repository.dart';
import 'package:fixonway/repositories/mock_data_store.dart';
import 'package:fixonway/repositories/mock_request_repository.dart';
import 'package:fixonway/repositories/mock_review_repository.dart';
import 'package:fixonway/repositories/request_repository.dart';
import 'package:fixonway/services/chat_service.dart';
import 'package:fixonway/services/job_service.dart';
import 'package:fixonway/services/payment_service.dart';
import 'package:fixonway/services/request_service.dart';
import 'package:fixonway/services/review_service.dart';
import 'package:fixonway/services/tracking.dart';

void main() {
  late DateTime clock;
  late MockDataStore store;
  late RequestRepository repo;
  late RequestService requests;
  late JobService jobs;
  late PaymentService payments;
  late ReviewService reviews;
  late ChatService chat;

  const AppUser ali = AppUser(
    id: 'u1',
    role: UserRole.customer,
    name: 'Ali Raza',
    phone: '+923001234567',
    email: 'ali.raza@example.pk',
  );
  const AppUser usman = AppUser(
    id: 'u2',
    role: UserRole.mechanic,
    name: 'Usman Ghani',
    phone: '+923217654321',
    email: 'usman@example.pk',
  );
  const Vehicle cultus = Vehicle(
    id: 'v0',
    ownerId: 'u1',
    type: VehicleType.car,
    make: 'Suzuki',
    model: 'Cultus',
    plate: 'ICT-1234',
  );

  setUp(() {
    clock = DateTime(2026, 1, 1, 12);
    store = MockDataStore(now: () => clock, simulatedDelay: Duration.zero);
    repo = MockRequestRepository(store);
    requests = RequestService(repo, now: () => clock);
    jobs = JobService(repo, now: () => clock);
    payments = PaymentService(repo, now: () => clock);
    reviews = ReviewService(
      repo,
      MockReviewRepository(store),
      now: () => clock,
    );
    chat = ChatService(MockChatRepository(store), repo, now: () => clock);
  });

  Future<ServiceRequest> open({ProblemType problem = ProblemType.flatTire}) {
    return requests.createRequest(
      customer: ali,
      vehicle: cultus,
      problem: problem,
      description: '',
      location: LatLng.islamabad,
      address: 'F-10 Markaz',
    );
  }

  /// A request accepted by Usman for PKR 1000, 10 minutes away.
  Future<ServiceRequest> accepted() async {
    final ServiceRequest r = await open();
    final Estimate e = await requests.submitEstimate(
      mechanicId: 'u2',
      requestId: r.id,
      amount: 1000,
      etaMinutes: 10,
    );
    return requests.acceptEstimate(r.id, e.id);
  }

  Future<ServiceRequest> completed() async {
    final ServiceRequest r = await accepted();
    await jobs.startTrip('u2', r.id);
    await jobs.markArrived('u2', r.id);
    await jobs.startWork('u2', r.id);
    return jobs.completeJob('u2', r.id);
  }

  Future<void> expectError(Future<Object?> Function() action, String part) async {
    try {
      await action();
      fail('Expected an AppException containing "$part"');
    } on AppException catch (e) {
      expect(e.message, contains(part));
    }
  }

  group('UC-26 incoming requests', () {
    test('an online matching mechanic sees the request', () async {
      final ServiceRequest r = await open();
      final List<IncomingRequest> list = await jobs.incoming('u2');
      expect(list.single.request.id, r.id);
      expect(list.single.distanceKm < 2, isTrue);
    });

    test('an offline mechanic sees nothing', () async {
      await open();
      expect(await jobs.incoming('m5'), isEmpty);
    });

    test('a mechanic who does not work on cars sees nothing', () async {
      await open();
      expect(await jobs.incoming('m3'), isEmpty);
    });

    test('a mechanic without that service sees nothing', () async {
      await open();
      expect(await jobs.incoming('m2'), isEmpty);
    });

    test('rejecting hides the request', () async {
      final ServiceRequest r = await open();
      await jobs.reject('u2', r.id);
      expect(await jobs.incoming('u2'), isEmpty);
    });

    test('an old request is hidden after 15 minutes', () async {
      await open();
      clock = clock.add(AppConstants.requestExpiry);
      expect(await jobs.incoming('u2'), isEmpty);
    });

    test('own estimate is shown on the request', () async {
      final ServiceRequest r = await open();
      await requests.submitEstimate(
        mechanicId: 'u2',
        requestId: r.id,
        amount: 900,
        etaMinutes: 10,
      );
      final List<IncomingRequest> list = await jobs.incoming('u2');
      expect(list.single.myEstimate?.amount, 900);
    });

    test('a declined estimate hides the request for that mechanic', () async {
      final ServiceRequest r = await open();
      final Estimate e = await requests.submitEstimate(
        mechanicId: 'u2',
        requestId: r.id,
        amount: 900,
        etaMinutes: 10,
      );
      await requests.declineEstimate(e.id);
      expect(await jobs.incoming('u2'), isEmpty);
    });
  });

  group('UC-29 / UC-31 job status', () {
    test('accepted request carries the promised arrival time', () async {
      final ServiceRequest r = await accepted();
      expect(r.etaMinutes, 10);
    });

    test('start trip records start point and time', () async {
      final ServiceRequest r = await accepted();
      final ServiceRequest t = await jobs.startTrip('u2', r.id);
      expect(t.status, RequestStatus.onTheWay);
      expect(t.startedAt, clock);
      expect(t.mechanicStart, const LatLng(33.6900, 73.0550));
    });

    test('full flow reaches completed', () async {
      final ServiceRequest done = await completed();
      expect(done.status, RequestStatus.completed);
      expect(done.completedAt, clock);
    });

    test('steps cannot be skipped', () async {
      final ServiceRequest r = await accepted();
      await expectError(() => jobs.markArrived('u2', r.id), 'cannot do this');
      await expectError(() => jobs.completeJob('u2', r.id), 'cannot do this');
    });

    test('another mechanic cannot move the job', () async {
      final ServiceRequest r = await accepted();
      await expectError(() => jobs.startTrip('m2', r.id), 'another mechanic');
    });

    test('the customer is notified at each step', () async {
      await completed();
      final List<AppNotification> list = await repo.notificationsFor('u1');
      final Iterable<String> titles = list.map((AppNotification n) => n.title);
      expect(titles, contains('Mechanic is on the way'));
      expect(titles, contains('Mechanic has arrived'));
      expect(titles, contains('Work started'));
      expect(titles, contains('Job completed'));
    });
  });

  group('UC-15 tracking maths', () {
    final DateTime t0 = DateTime(2026, 1, 1, 12);

    test('progress is 0 at the start and 1 at the end', () {
      expect(
        Tracking.progress(startedAt: t0, etaMinutes: 10, now: t0),
        0,
      );
      expect(
        Tracking.progress(
          startedAt: t0,
          etaMinutes: 10,
          now: t0.add(const Duration(seconds: 60)),
        ),
        1,
      );
    });

    test('progress is 0.5 halfway (10 min trip runs 10x faster)', () {
      final double p = Tracking.progress(
        startedAt: t0,
        etaMinutes: 10,
        now: t0.add(const Duration(seconds: 30)),
      );
      expect(p, closeTo(0.5, 0.001));
    });

    test('progress never goes beyond 1 or below 0', () {
      expect(
        Tracking.progress(
          startedAt: t0,
          etaMinutes: 10,
          now: t0.add(const Duration(hours: 5)),
        ),
        1,
      );
      expect(
        Tracking.progress(
          startedAt: t0,
          etaMinutes: 10,
          now: t0.subtract(const Duration(seconds: 5)),
        ),
        0,
      );
    });

    test('position is the midpoint at 0.5', () {
      final LatLng p = Tracking.position(
        start: const LatLng(0, 0),
        end: const LatLng(10, 20),
        progress: 0.5,
      );
      expect(p, const LatLng(5, 10));
    });

    test('remaining minutes', () {
      expect(Tracking.remainingMinutes(etaMinutes: 10, progress: 0.5), 5);
      expect(Tracking.remainingMinutes(etaMinutes: 10, progress: 0.99), 1);
      expect(Tracking.remainingMinutes(etaMinutes: 10, progress: 1), 0);
    });
  });

  group('UC-18 / UC-40 payment', () {
    test('wallet payment is confirmed at once', () async {
      final ServiceRequest r = await completed();
      final ServiceRequest paid = await payments.pay(
        requestId: r.id,
        customerId: 'u1',
        method: PaymentMethod.jazzcash,
        account: '0300 1234567',
      );
      expect(paid.status, RequestStatus.paid);
      expect(paid.paidAt, clock);
      final MechanicProfile? m = await repo.mechanic('u2');
      expect(m!.jobsDone, 151);
    });

    test('cash waits for the mechanic to confirm', () async {
      final ServiceRequest r = await completed();
      final ServiceRequest waiting = await payments.pay(
        requestId: r.id,
        customerId: 'u1',
        method: PaymentMethod.cash,
      );
      expect(waiting.status, RequestStatus.completed);
      expect(waiting.awaitingCashConfirmation, isTrue);
      final ServiceRequest paid =
          await payments.confirmCash(requestId: r.id, mechanicId: 'u2');
      expect(paid.status, RequestStatus.paid);
    });

    test('cash cannot be confirmed before the customer chose it', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => payments.confirmCash(requestId: r.id, mechanicId: 'u2'),
        'not chosen cash',
      );
    });

    test('only the assigned mechanic can confirm', () async {
      final ServiceRequest r = await completed();
      await payments.pay(
        requestId: r.id,
        customerId: 'u1',
        method: PaymentMethod.cash,
      );
      await expectError(
        () => payments.confirmCash(requestId: r.id, mechanicId: 'm2'),
        'another mechanic',
      );
    });

    test('paying before completion is rejected', () async {
      final ServiceRequest r = await accepted();
      await expectError(
        () => payments.pay(
          requestId: r.id,
          customerId: 'u1',
          method: PaymentMethod.cash,
        ),
        'completed',
      );
    });

    test('wallet needs a valid number', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => payments.pay(
          requestId: r.id,
          customerId: 'u1',
          method: PaymentMethod.easypaisa,
          account: '123',
        ),
        'valid mobile',
      );
    });

    test('the failing demo number is declined', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => payments.pay(
          requestId: r.id,
          customerId: 'u1',
          method: PaymentMethod.jazzcash,
          account: '0300 0000000',
        ),
        'Payment failed',
      );
    });

    test('someone else cannot pay', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => payments.pay(
          requestId: r.id,
          customerId: 'u9',
          method: PaymentMethod.cash,
        ),
        'not your request',
      );
    });

    test('a paid request cannot be paid again', () async {
      final ServiceRequest r = await completed();
      await payments.pay(
        requestId: r.id,
        customerId: 'u1',
        method: PaymentMethod.jazzcash,
        account: '0300 1234567',
      );
      await expectError(
        () => payments.pay(
          requestId: r.id,
          customerId: 'u1',
          method: PaymentMethod.cash,
        ),
        'completed',
      );
    });
  });

  Future<ServiceRequest> paidRequest() async {
    final ServiceRequest r = await completed();
    return payments.pay(
      requestId: r.id,
      customerId: 'u1',
      method: PaymentMethod.jazzcash,
      account: '0300 1234567',
    );
  }

  group('UC-19 review', () {
    test('cannot review before paying', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => reviews.submitReview(requestId: r.id, customerId: 'u1', rating: 5),
        'after paying',
      );
    });

    test('rating must be 1 to 5', () async {
      final ServiceRequest r = await paidRequest();
      await expectError(
        () => reviews.submitReview(requestId: r.id, customerId: 'u1', rating: 0),
        '1 and 5',
      );
      await expectError(
        () => reviews.submitReview(requestId: r.id, customerId: 'u1', rating: 6),
        '1 and 5',
      );
    });

    test('comment over 300 characters is rejected', () async {
      final ServiceRequest r = await paidRequest();
      await expectError(
        () => reviews.submitReview(
          requestId: r.id,
          customerId: 'u1',
          rating: 4,
          comment: 'x' * 301,
        ),
        '300',
      );
    });

    test('a review closes the request and updates the rating', () async {
      final ServiceRequest r = await paidRequest();
      final Review review = await reviews.submitReview(
        requestId: r.id,
        customerId: 'u1',
        rating: 5,
        comment: 'Great',
      );
      expect(review.rating, 5);
      final ServiceRequest after = await requests.requestById(r.id);
      expect(after.status, RequestStatus.closed);
      final MechanicProfile? m = await repo.mechanic('u2');
      expect(m!.reviewCount, 133);
      expect(m.rating, closeTo((4.8 * 132 + 5) / 133, 0.0001));
    });

    test('a review of 1 star is accepted', () async {
      final ServiceRequest r = await paidRequest();
      final Review review = await reviews.submitReview(
        requestId: r.id,
        customerId: 'u1',
        rating: 1,
      );
      expect(review.rating, 1);
    });

    test('skipping closes the request without a review', () async {
      final ServiceRequest r = await paidRequest();
      await reviews.skipReview(r.id, 'u1');
      final ServiceRequest after = await requests.requestById(r.id);
      expect(after.status, RequestStatus.closed);
      expect(await reviews.reviewOf(r.id), isNull);
    });

    test('the mechanic sees the review in the list', () async {
      final ServiceRequest r = await paidRequest();
      await reviews.submitReview(requestId: r.id, customerId: 'u1', rating: 5);
      final List<Review> list = await reviews.reviewsOfMechanic('u2');
      expect(list.length, 3);
      expect(list.first.requestId, r.id);
    });
  });

  group('UC-22 complaint', () {
    test('too short a description is rejected', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => reviews.submitComplaint(
          requestId: r.id,
          customerId: 'u1',
          category: ComplaintCategory.overcharged,
          description: '123456789',
        ),
        'at least 10',
      );
    });

    test('10 characters are accepted and the request becomes disputed', () async {
      final ServiceRequest r = await completed();
      await reviews.submitComplaint(
        requestId: r.id,
        customerId: 'u1',
        category: ComplaintCategory.poorWork,
        description: '1234567890',
      );
      final ServiceRequest after = await requests.requestById(r.id);
      expect(after.status, RequestStatus.disputed);
    });

    test('description over 500 characters is rejected', () async {
      final ServiceRequest r = await completed();
      await expectError(
        () => reviews.submitComplaint(
          requestId: r.id,
          customerId: 'u1',
          category: ComplaintCategory.other,
          description: 'x' * 501,
        ),
        '500',
      );
    });

    test('only one complaint per request', () async {
      final ServiceRequest r = await completed();
      await reviews.submitComplaint(
        requestId: r.id,
        customerId: 'u1',
        category: ComplaintCategory.poorWork,
        description: 'The tyre is loose again.',
      );
      await expectError(
        () => reviews.submitComplaint(
          requestId: r.id,
          customerId: 'u1',
          category: ComplaintCategory.poorWork,
          description: 'Another complaint text.',
        ),
        'already submitted',
      );
    });

    test('a complaint before the job is done is rejected', () async {
      final ServiceRequest r = await accepted();
      await expectError(
        () => reviews.submitComplaint(
          requestId: r.id,
          customerId: 'u1',
          category: ComplaintCategory.noShow,
          description: 'He never came here.',
        ),
        'completed',
      );
    });

    test('a complaint on a paid request keeps the status', () async {
      final ServiceRequest r = await paidRequest();
      await reviews.submitComplaint(
        requestId: r.id,
        customerId: 'u1',
        category: ComplaintCategory.behaviour,
        description: 'He was very rude to me.',
      );
      final ServiceRequest after = await requests.requestById(r.id);
      expect(after.status, RequestStatus.paid);
    });
  });

  group('UC-16 chat', () {
    test('customer and mechanic can talk after assignment', () async {
      final ServiceRequest r = await accepted();
      await chat.send(requestId: r.id, sender: ali, text: 'Hello');
      clock = clock.add(const Duration(seconds: 5));
      await chat.send(requestId: r.id, sender: usman, text: 'On my way');
      final List<ChatMessage> list = await chat.messages(r.id, 'u1');
      expect(list.map((ChatMessage m) => m.text), <String>['Hello', 'On my way']);
    });

    test('no chat before a mechanic is assigned', () async {
      final ServiceRequest r = await open();
      await expectError(
        () => chat.send(requestId: r.id, sender: ali, text: 'Hi'),
        'mechanic is assigned',
      );
    });

    test('a stranger cannot read or write', () async {
      final ServiceRequest r = await accepted();
      const AppUser stranger = AppUser(
        id: 'u9',
        role: UserRole.customer,
        name: 'Stranger',
        phone: '+923331234567',
        email: 's@example.pk',
      );
      await expectError(() => chat.messages(r.id, 'u9'), 'not part');
      await expectError(
        () => chat.send(requestId: r.id, sender: stranger, text: 'Hi'),
        'not part',
      );
    });

    test('empty and 501 character messages are rejected, 500 is fine', () async {
      final ServiceRequest r = await accepted();
      await expectError(
        () => chat.send(requestId: r.id, sender: ali, text: '   '),
        'Type a message',
      );
      await expectError(
        () => chat.send(requestId: r.id, sender: ali, text: 'x' * 501),
        '500',
      );
      await chat.send(requestId: r.id, sender: ali, text: 'x' * 500);
    });

    test('chat stays open after completion but not after closing', () async {
      final ServiceRequest r = await completed();
      await chat.send(requestId: r.id, sender: ali, text: 'Thanks');
      await payments.pay(
        requestId: r.id,
        customerId: 'u1',
        method: PaymentMethod.jazzcash,
        account: '0300 1234567',
      );
      await expectError(
        () => chat.send(requestId: r.id, sender: ali, text: 'Again'),
        'mechanic is assigned',
      );
    });
  });
}
