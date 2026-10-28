/// UC-18: how the customer pays.
enum PaymentMethod {
  cash('Cash to mechanic'),
  jazzcash('JazzCash'),
  easypaisa('EasyPaisa');

  const PaymentMethod(this.label);

  final String label;

  /// Wallet payments need a mobile number and are confirmed at once.
  bool get isWallet => this != PaymentMethod.cash;
}
