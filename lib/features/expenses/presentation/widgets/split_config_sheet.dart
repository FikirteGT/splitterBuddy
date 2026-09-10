import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:splitterbuddy/core/constants/app_colors.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';
import 'package:splitterbuddy/core/utils/currency_formatter.dart';
import 'package:splitterbuddy/features/balance/services/split_engine.dart';

class SplitConfigResult {
  final String splitType;
  final Map<String, double>? splitDetails;
  final String? splitSingleMemberId;

  const SplitConfigResult({
    required this.splitType,
    this.splitDetails,
    this.splitSingleMemberId,
  });
}

class SplitConfigSheet extends StatefulWidget {
  final double totalAmount;
  final List<String> memberIds;
  final Map<String, String> memberNames;
  final String initialSplitType;
  final Map<String, double>? initialSplitDetails;
  final String? initialSingleMemberId;

  const SplitConfigSheet({
    super.key,
    required this.totalAmount,
    required this.memberIds,
    required this.memberNames,
    this.initialSplitType = AppConstants.splitEqual,
    this.initialSplitDetails,
    this.initialSingleMemberId,
  });

  static Future<SplitConfigResult?> show(
    BuildContext context, {
    required double totalAmount,
    required List<String> memberIds,
    required Map<String, String> memberNames,
    String initialSplitType = AppConstants.splitEqual,
    Map<String, double>? initialSplitDetails,
    String? initialSingleMemberId,
  }) {
    return showModalBottomSheet<SplitConfigResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SplitConfigSheet(
        totalAmount: totalAmount,
        memberIds: memberIds,
        memberNames: memberNames,
        initialSplitType: initialSplitType,
        initialSplitDetails: initialSplitDetails,
        initialSingleMemberId: initialSingleMemberId,
      ),
    );
  }

  @override
  State<SplitConfigSheet> createState() => _SplitConfigSheetState();
}

class _SplitConfigSheetState extends State<SplitConfigSheet> {
  late String _selectedSplitType;
  late String? _selectedSingleMemberId;
  final Map<String, TextEditingController> _controllers = {};
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _selectedSplitType = widget.initialSplitType;
    _selectedSingleMemberId = widget.initialSingleMemberId ?? (widget.memberIds.isNotEmpty ? widget.memberIds.first : null);

    for (final id in widget.memberIds) {
      double initialVal = 0.0;
      if (widget.initialSplitDetails != null && widget.initialSplitDetails!.containsKey(id)) {
        initialVal = widget.initialSplitDetails![id]!;
      } else if (_selectedSplitType == AppConstants.splitEqual && widget.memberIds.isNotEmpty) {
        initialVal = widget.totalAmount / widget.memberIds.length;
      } else if (_selectedSplitType == AppConstants.splitPercentage && widget.memberIds.isNotEmpty) {
        initialVal = 100.0 / widget.memberIds.length;
      }
      _controllers[id] = TextEditingController(
        text: initialVal > 0 ? initialVal.toStringAsFixed(initialVal.truncateToDouble() == initialVal ? 0 : 2) : '',
      );
    }

    _validate();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _validate() {
    final details = <String, double>{};
    for (final entry in _controllers.entries) {
      final parsed = double.tryParse(entry.value.text.trim()) ?? 0.0;
      details[entry.key] = parsed;
    }

    setState(() {
      _validationError = SplitEngine.validateSplit(
        totalAmount: widget.totalAmount,
        splitType: _selectedSplitType,
        memberIds: widget.memberIds,
        splitDetails: details,
        singleMemberId: _selectedSingleMemberId,
      );
    });
  }

  void _handleSave() {
    _validate();
    if (_validationError != null) return;

    final details = <String, double>{};
    for (final entry in _controllers.entries) {
      final parsed = double.tryParse(entry.value.text.trim()) ?? 0.0;
      details[entry.key] = parsed;
    }

    Navigator.of(context).pop(
      SplitConfigResult(
        splitType: _selectedSplitType,
        splitDetails: (_selectedSplitType == AppConstants.splitCustom || _selectedSplitType == AppConstants.splitPercentage)
            ? details
            : null,
        splitSingleMemberId: _selectedSplitType == AppConstants.splitSingle ? _selectedSingleMemberId : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Split Configuration',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Total Expense: ${CurrencyFormatter.format(widget.totalAmount)}',
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
            ),
            const SizedBox(height: 16),

            // Split Type Options
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildSplitTypeChip(AppConstants.splitEqual, 'Equal (50/50)', Icons.pie_chart_outline_rounded),
                _buildSplitTypeChip(AppConstants.splitCustom, 'Custom Amounts', Icons.tune_rounded),
                _buildSplitTypeChip(AppConstants.splitPercentage, 'Percentages', Icons.percent_rounded),
                _buildSplitTypeChip(AppConstants.splitSingle, 'Paid for One', Icons.person_outline_rounded),
              ],
            ),
            const SizedBox(height: 20),

            // Mode specific inputs
            if (_selectedSplitType == AppConstants.splitEqual) ...[
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.surfaceElevated,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.cardBorder),
                ),
                child: Text(
                  'The total of ${CurrencyFormatter.format(widget.totalAmount)} will be divided equally (${CurrencyFormatter.format(widget.totalAmount / (widget.memberIds.isEmpty ? 1 : widget.memberIds.length))} per person).',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ),
            ] else if (_selectedSplitType == AppConstants.splitCustom) ...[
              ...widget.memberIds.map((id) {
                final name = widget.memberNames[id] ?? 'Member';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _controllers[id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                          ],
                          onChanged: (_) => _validate(),
                          decoration: InputDecoration(
                            prefixText: 'ETB ',
                            hintText: '0.00',
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (_selectedSplitType == AppConstants.splitPercentage) ...[
              ...widget.memberIds.map((id) {
                final name = widget.memberNames[id] ?? 'Member';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                      ),
                      Expanded(
                        flex: 3,
                        child: TextField(
                          controller: _controllers[id],
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,1}')),
                          ],
                          onChanged: (_) => _validate(),
                          decoration: InputDecoration(
                            suffixText: '%',
                            hintText: '50.0',
                            filled: true,
                            fillColor: AppColors.surfaceElevated,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ] else if (_selectedSplitType == AppConstants.splitSingle) ...[
              const Text('Select who this expense was paid for:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ...widget.memberIds.map((id) {
                final name = widget.memberNames[id] ?? 'Member';
                return RadioListTile<String>(
                  value: id,
                  // ignore: deprecated_member_use
                  groupValue: _selectedSingleMemberId,
                  title: Text(name, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary)),
                  // ignore: deprecated_member_use
                  onChanged: (val) {
                    setState(() => _selectedSingleMemberId = val);
                    _validate();
                  },
                );
              }),
            ],

            if (_validationError != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.badgeRedBg,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded, size: 16, color: AppColors.error),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _validationError!,
                        style: const TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _validationError == null ? _handleSave : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Confirm Split', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSplitTypeChip(String type, String label, IconData icon) {
    final isSelected = _selectedSplitType == type;
    return ChoiceChip(
      selected: isSelected,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: isSelected ? Colors.white : AppColors.textSecondary),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceElevated,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppColors.textSecondary,
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
      onSelected: (selected) {
        if (selected) {
          setState(() {
            _selectedSplitType = type;
            _validate();
          });
        }
      },
    );
  }
}
