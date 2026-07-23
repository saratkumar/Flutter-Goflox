import 'package:flutter/material.dart';
import '../utils/app_colors.dart';

/// Shared "how far back" window for history/timeline views (Resolved QR
/// Payments, Transaction History, client booking History) — default 1
/// month, capped at 3 months so a single client-side fetch/filter over the
/// Sheet mirror never has to scan unbounded history.
enum TimelineRange {
  oneMonth(30, '1 Month'),
  twoMonths(60, '2 Months'),
  threeMonths(90, '3 Months');

  final int days;
  final String label;
  const TimelineRange(this.days, this.label);

  DateTime get cutoff =>
      DateTime.now().subtract(Duration(days: days));
}

/// Row of choice chips to switch between [TimelineRange] presets. Defaults
/// to [TimelineRange.oneMonth] via the caller's initial `value`.
class TimelineRangeSelector extends StatelessWidget {
  final TimelineRange value;
  final ValueChanged<TimelineRange> onChanged;

  const TimelineRangeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: TimelineRange.values.map((r) {
        final selected = r == value;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(r.label),
            selected: selected,
            onSelected: (_) => onChanged(r),
            selectedColor: AppColors.primary.withValues(alpha: 0.15),
            labelStyle: TextStyle(
              fontSize: 12,
              color: selected ? AppColors.primary : AppColors.textSecondary,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        );
      }).toList(),
    );
  }
}

/// Parses the loosely-typed date/timestamp strings that come back from the
/// Sheet mirror (ISO `timestamp` on ActivityLog rows, plain `YYYY-MM-DD`
/// `date` on Transactions rows) and reports whether they fall within
/// [range]. Rows with an unparseable date are excluded rather than crashing
/// or being assumed-recent.
bool isWithinRange(String? rawDate, TimelineRange range) {
  if (rawDate == null || rawDate.isEmpty) return false;
  final dt = DateTime.tryParse(rawDate);
  if (dt == null) return false;
  return !dt.isBefore(range.cutoff);
}
