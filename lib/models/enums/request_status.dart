/// Life cycle of a service request (see the state diagram in the SDA).
enum RequestStatus {
  pending,
  estimated,
  accepted,
  onTheWay,
  arrived,
  working,
  completed,
  paid,
  disputed,
  closed,
  cancelled,
  expired;

  static const Map<RequestStatus, Set<RequestStatus>> _allowed =
      <RequestStatus, Set<RequestStatus>>{
    RequestStatus.pending: <RequestStatus>{
      RequestStatus.estimated,
      RequestStatus.cancelled,
      RequestStatus.expired,
    },
    RequestStatus.estimated: <RequestStatus>{
      RequestStatus.accepted,
      RequestStatus.pending,
      RequestStatus.cancelled,
    },
    RequestStatus.accepted: <RequestStatus>{
      RequestStatus.onTheWay,
      RequestStatus.cancelled,
    },
    RequestStatus.onTheWay: <RequestStatus>{
      RequestStatus.arrived,
      RequestStatus.cancelled,
    },
    RequestStatus.arrived: <RequestStatus>{
      RequestStatus.working,
      RequestStatus.cancelled,
    },
    RequestStatus.working: <RequestStatus>{RequestStatus.completed},
    RequestStatus.completed: <RequestStatus>{
      RequestStatus.paid,
      RequestStatus.disputed,
    },
    RequestStatus.disputed: <RequestStatus>{
      RequestStatus.paid,
      RequestStatus.closed,
    },
    RequestStatus.paid: <RequestStatus>{RequestStatus.closed},
  };

  /// True when moving from this status to [next] is allowed.
  bool canMoveTo(RequestStatus next) => _allowed[this]?.contains(next) ?? false;

  /// A request in one of these statuses can no longer change.
  bool get isFinished =>
      this == RequestStatus.closed ||
      this == RequestStatus.cancelled ||
      this == RequestStatus.expired;
}
