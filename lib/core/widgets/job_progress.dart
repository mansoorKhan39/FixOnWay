import 'package:flutter/material.dart';

import '../../models/enums/request_status.dart';
import '../theme/app_theme.dart';

/// The step bar shown on the request and job screens.
class JobProgress extends StatelessWidget {
  const JobProgress({super.key, required this.status});

  final RequestStatus status;

  static const List<RequestStatus> _steps = <RequestStatus>[
    RequestStatus.pending,
    RequestStatus.accepted,
    RequestStatus.onTheWay,
    RequestStatus.arrived,
    RequestStatus.working,
    RequestStatus.completed,
    RequestStatus.paid,
  ];

  static const List<String> _labels = <String>[
    'Request',
    'Assigned',
    'On way',
    'Arrived',
    'Working',
    'Done',
    'Paid',
  ];

  int get _current {
    if (status == RequestStatus.estimated) return 0;
    final int i = _steps.indexOf(status);
    if (i >= 0) return i;
    if (status == RequestStatus.closed) return 6;
    if (status == RequestStatus.disputed) return 5;
    return -1;
  }

  @override
  Widget build(BuildContext context) {
    final int current = _current;
    if (current < 0) return const SizedBox.shrink();
    return Row(
      children: <Widget>[
        for (int i = 0; i < _steps.length; i++)
          Expanded(
            child: Column(
              children: <Widget>[
                Container(
                  height: 6,
                  margin: const EdgeInsets.symmetric(horizontal: 2),
                  decoration: BoxDecoration(
                    color: i <= current
                        ? AppColors.primary
                        : Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _labels[i],
                  style: TextStyle(
                    fontSize: 10,
                    color: i <= current ? AppColors.text : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
