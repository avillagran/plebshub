import 'package:flutter/material.dart';
import 'package:plebshub_ui/plebshub_ui.dart';

/// A widget to pick zap amounts.
///
/// Shows common amounts and allows custom input.
class ZapAmountPicker extends StatefulWidget {
  const ZapAmountPicker({
    super.key,
    this.initialAmount = 21,
    required this.onAmountSelected,
  });

  /// Initial selected amount in sats.
  final int initialAmount;

  /// Callback when an amount is selected.
  final void Function(int amount) onAmountSelected;

  @override
  State<ZapAmountPicker> createState() => _ZapAmountPickerState();
}

class _ZapAmountPickerState extends State<ZapAmountPicker> {
  late int _selectedAmount;
  final _customController = TextEditingController();

  static const _presetAmounts = [21, 100, 500, 1000, 5000, 10000];

  @override
  void initState() {
    super.initState();
    _selectedAmount = widget.initialAmount;
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _selectAmount(int amount) {
    setState(() => _selectedAmount = amount);
    widget.onAmountSelected(amount);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select Amount',
          style: AppTypography.titleMedium,
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _presetAmounts.map((amount) {
            final isSelected = amount == _selectedAmount;
            return GestureDetector(
              onTap: () => _selectAmount(amount),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.zapOrange : AppColors.surface,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.zapOrange : AppColors.border,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.bolt,
                      size: 16,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.zapOrange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatAmount(amount),
                      style: AppTypography.labelLarge.copyWith(
                        color: isSelected
                            ? AppColors.textPrimary
                            : AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _customController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Custom amount',
            suffixText: 'sats',
          ),
          onSubmitted: (value) {
            final amount = int.tryParse(value);
            if (amount != null && amount > 0) {
              _selectAmount(amount);
            }
          },
        ),
      ],
    );
  }

  String _formatAmount(int amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toString();
  }
}
