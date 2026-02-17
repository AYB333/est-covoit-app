import 'package:flutter/material.dart';

import '../config/translations.dart';
import '../repositories/safety_repository.dart';

// --- SCREEN: REPORT USER ---
class ReportScreen extends StatefulWidget {
  final String reporterId;
  final String reportedUserId;
  final String contextId;

  const ReportScreen({
    super.key,
    required this.reporterId,
    required this.reportedUserId,
    required this.contextId,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  // --- REASONS LIST ---
  static const List<String> _reasons = <String>[
    'spam',
    'abuse',
    'fake_profile',
    'other',
  ];

  // --- STATE ---
  final TextEditingController _detailsController = TextEditingController();
  String _selectedReason = _reasons.first;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  // --- SUBMIT REPORT ---
  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await SafetyRepository().reportUser(
        reporterId: widget.reporterId,
        reportedUserId: widget.reportedUserId,
        reason: _selectedReason,
        details: _detailsController.text.trim(),
        contextType: 'chat',
        contextId: widget.contextId,
      );
      if (!mounted) return;
      Navigator.pop(context, 'sent');
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(Translations.getText(context, 'error_processing'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      // --- APPBAR ---
      appBar: AppBar(
        title: Text(Translations.getText(context, 'report_user')),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [scheme.primary, scheme.secondary],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      // --- BODY: FORM ---
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: scheme.outline.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  Translations.getText(context, 'report_reason'),
                  style: TextStyle(
                    color: scheme.primary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  initialValue: _selectedReason,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.primary),
                    ),
                  ),
                  items: _reasons
                      .map(
                        (reason) => DropdownMenuItem<String>(
                          value: reason,
                          child: Text(Translations.getText(context, 'report_reason_$reason')),
                        ),
                      )
                      .toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _selectedReason = value);
                        },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _detailsController,
                  enabled: !_isSubmitting,
                  maxLines: 5,
                  decoration: InputDecoration(
                    hintText: Translations.getText(context, 'report_details_hint'),
                    filled: true,
                    fillColor: scheme.surfaceContainerLowest.withValues(alpha: 0.35),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.5)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.outline.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(color: scheme.primary),
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: scheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(Translations.getText(context, 'submit_report')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
