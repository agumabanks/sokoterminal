/// BNPL seller enrollment status returned by the backend.
class BnplSellerStatus {
  const BnplSellerStatus({
    required this.status,
    this.message,
    this.isEligible,
  });

  factory BnplSellerStatus.fromJson(Map<String, dynamic> json) {
    return BnplSellerStatus(
      status: json['status']?.toString().toLowerCase() ?? 'not_enrolled',
      message: json['message']?.toString(),
      isEligible: json['is_eligible'] == true || json['is_eligible'] == 1,
    );
  }

  /// One of: `not_enrolled`, `pending`, `active`, `suspended`.
  final String status;
  final String? message;
  final bool? isEligible;

  bool get isNotEnrolled => status == 'not_enrolled';
  bool get isPending => status == 'pending';
  bool get isActive => status == 'active';
  bool get isSuspended => status == 'suspended';

  Map<String, dynamic> toJson() => {
        'status': status,
        if (message != null) 'message': message,
        if (isEligible != null) 'is_eligible': isEligible,
      };
}
