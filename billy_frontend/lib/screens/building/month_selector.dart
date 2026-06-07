import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';

/// YYYYMM 월 선택기 (이전/다음 스텝퍼).
class MonthSelector extends StatelessWidget {
  final String month; // YYYYMM
  final ValueChanged<String> onChanged;
  const MonthSelector({super.key, required this.month, required this.onChanged});

  String _shift(int delta) {
    final y = int.parse(month.substring(0, 4));
    final m = int.parse(month.substring(4, 6));
    final d = DateTime(y, m + delta, 1);
    return '${d.year}${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BillyColors.card(),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          IconButton(
            onPressed: () => onChanged(_shift(-1)),
            icon: const Icon(Icons.chevron_left_rounded, color: BillyColors.primary),
          ),
          Expanded(
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.calendar_month_rounded, size: 18, color: BillyColors.primary),
                  const SizedBox(width: 8),
                  Text(
                    chargeMonthLabel(month),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: BillyColors.textPrimary),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            onPressed: () => onChanged(_shift(1)),
            icon: const Icon(Icons.chevron_right_rounded, color: BillyColors.primary),
          ),
        ],
      ),
    );
  }
}
