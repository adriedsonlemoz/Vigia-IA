import 'package:flutter/material.dart';

import '../models/bike_approach_status.dart';

class BikeApproachBanner extends StatelessWidget {
  const BikeApproachBanner({
    super.key,
    required this.status,
  });

  final BikeApproachStatus status;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final scheme = Theme.of(context).colorScheme;
    final color = switch (status.level) {
      BikeApproachLevel.critical => scheme.error,
      BikeApproachLevel.warning => const Color(0xFFF57C00),
      BikeApproachLevel.watch => const Color(0xFF1565C0),
      BikeApproachLevel.clear => Colors.transparent,
    };
    if (!status.visible) return const SizedBox.shrink();

    return IgnorePointer(
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: compact ? 360 : 520),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 10 : 14,
            vertical: compact ? 6 : 9,
          ),
          decoration: BoxDecoration(
            color: color.withValues(
              alpha: status.level == BikeApproachLevel.watch ? 0.78 : 0.92,
            ),
            borderRadius: BorderRadius.circular(compact ? 13 : 16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
            boxShadow: const [
              BoxShadow(color: Colors.black45, blurRadius: 12),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                status.level == BikeApproachLevel.critical
                    ? Icons.warning_amber_rounded
                    : Icons.directions_car_filled_rounded,
                color: Colors.white,
                size: compact ? 19 : 23,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: compact ? 11 : 13,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '${status.ttcLabel}${status.simulated ? ' • SIMULAÇÃO' : ' • estimativa visual'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: compact ? 9 : 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
