import '../core/errors/app_exception.dart';
import '../core/utils/validators.dart';
import '../models/app_notification.dart';
import '../models/enums/payment_method.dart';
import '../models/enums/request_status.dart';
import '../models/mechanic_profile.dart';
import '../models/service_request.dart';
import '../repositories/request_repository.dart';

/// Strategy pattern: every payment method decides on its own how money moves.
abstract class PaymentStrategy {
  PaymentMethod get method;

  /// Returns true when the money has been received right away.
  Future<bool> pay({required int amount, String? account});
}

/// The customer hands over cash; the mechanic confirms it later (UC-40).
class CashPayment implements PaymentStrategy {
  @override
  PaymentMethod get method => PaymentMethod.cash;

  @override
  Future<bool> pay({required int amount, String? account}) async => false;
}

/// JazzCash / EasyPaisa. This is a simulation: a real gateway comes later.
class WalletPayment implements PaymentStrategy {
  WalletPayment(this.method);

  /// This number always fails, so the error path can be tried.
  static const String failingNumber = '+923000000000';

  @override
  final PaymentMethod method;

  @override
  Future<bool> pay({required int amount, String? account}) async {
    final String? error = Validators.phone(account);
    if (error != null) throw AppException(error);
    if (Validators.normalizePhone(account!) == failingNumber) {
      throw const AppException('Payment failed. Please try another method.');
    }
    return true;
  }
}

/// UC-18 Pay for service and UC-40 Confirm payment.
class PaymentService {
  PaymentService(this._repository, {DateTime Function()? now})
      : _now = now ?? DateTime.now {
    _strategies = <PaymentMethod, PaymentStrategy>{
      PaymentMethod.cash: CashPayment(),
      PaymentMethod.jazzcash: WalletPayment(PaymentMethod.jazzcash),
      PaymentMethod.easypaisa: WalletPayment(PaymentMethod.easypaisa),
    };
  }

  final RequestRepository _repository;
  final DateTime Function() _now;
  late final Map<PaymentMethod, PaymentStrategy> _strategies;

  Future<ServiceRequest> _request(String id) async {
    final ServiceRequest? r = await _repository.byId(id);
    if (r == null) throw const AppException('Request not found.');
    return r;
  }

  Future<void> _notify(String userId, String title, String body, String id) {
    return _repository.addNotification(
      AppNotification(
        id: '',
        userId: userId,
        title: title,
        body: body,
        createdAt: _now(),
        requestId: id,
      ),
    );
  }

  Future<ServiceRequest> _markPaid(
    ServiceRequest r,
    PaymentMethod method,
  ) async {
    final DateTime now = _now();
    final ServiceRequest paid = r.copyWith(
      status: RequestStatus.paid,
      updatedAt: now,
      paymentMethod: method,
      paidAt: now,
    );
    await _repository.update(paid);
    if (r.mechanicId != null) {
      final MechanicProfile? m = await _repository.mechanic(r.mechanicId!);
      if (m != null) {
        await _repository.saveMechanic(m.copyWith(jobsDone: m.jobsDone + 1));
      }
      await _notify(
        r.mechanicId!,
        'Payment received',
        'PKR ${r.agreedAmount} for the ${r.problem.label} job.',
        r.id,
      );
    }
    return paid;
  }

  /// UC-18.
  Future<ServiceRequest> pay({
    required String requestId,
    required String customerId,
    required PaymentMethod method,
    String? account,
  }) async {
    final ServiceRequest r = await _request(requestId);
    if (r.customerId != customerId) {
      throw const AppException('This is not your request.');
    }
    if (r.status != RequestStatus.completed) {
      throw const AppException('You can pay once the job is completed.');
    }
    final int amount = r.agreedAmount ?? 0;
    if (amount <= 0) throw const AppException('There is nothing to pay.');

    final bool paidNow =
        await _strategies[method]!.pay(amount: amount, account: account);
    if (paidNow) return _markPaid(r, method);

    final ServiceRequest waiting = r.copyWith(
      paymentMethod: method,
      updatedAt: _now(),
    );
    await _repository.update(waiting);
    if (r.mechanicId != null) {
      await _notify(
        r.mechanicId!,
        'Customer will pay cash',
        'Please confirm once you receive PKR $amount.',
        r.id,
      );
    }
    return waiting;
  }

  /// UC-40: the mechanic confirms that the cash arrived.
  Future<ServiceRequest> confirmCash({
    required String requestId,
    required String mechanicId,
  }) async {
    final ServiceRequest r = await _request(requestId);
    if (r.mechanicId != mechanicId) {
      throw const AppException('This job belongs to another mechanic.');
    }
    if (!r.awaitingCashConfirmation) {
      throw const AppException('The customer has not chosen cash payment.');
    }
    final ServiceRequest paid = await _markPaid(r, PaymentMethod.cash);
    await _notify(
      r.customerId,
      'Payment confirmed',
      'Thank you! Please rate your mechanic.',
      r.id,
    );
    return paid;
  }
}
