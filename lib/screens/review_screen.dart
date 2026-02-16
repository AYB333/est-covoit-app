import 'package:flutter/material.dart';

import '../config/translations.dart';
import '../models/booking.dart';
import '../repositories/review_repository.dart';

class ReviewScreen extends StatefulWidget {
  final Booking booking;
  final String reviewerId;

  const ReviewScreen({
    super.key,
    required this.booking,
    required this.reviewerId,
  });

  @override
  State<ReviewScreen> createState() => _ReviewScreenState();
}

class _ReviewScreenState extends State<ReviewScreen> {
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 5;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      await ReviewRepository().submitReview(
        bookingId: widget.booking.id,
        rideId: widget.booking.rideId,
        reviewerId: widget.reviewerId,
        revieweeId: widget.booking.driverId,
        rating: _selectedRating,
        comment: _commentController.text.trim(),
      );
      if (!mounted) return;
      Navigator.pop(context, 'submitted');
    } catch (e) {
      if (!mounted) return;
      if (e is StateError && e.message == 'review-exists') {
        Navigator.pop(context, 'exists');
        return;
      }
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(Translations.getText(context, 'review_error'))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.background,
      appBar: AppBar(
        title: Text(Translations.getText(context, 'review_title')),
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
                  Translations.getText(context, 'review_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final star = index + 1;
                    return IconButton(
                      onPressed: _isSubmitting
                          ? null
                          : () => setState(() => _selectedRating = star),
                      icon: Icon(
                        _selectedRating >= star ? Icons.star_rounded : Icons.star_border_rounded,
                        color: scheme.tertiary,
                        size: 34,
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  enabled: !_isSubmitting,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: Translations.getText(context, 'review_hint'),
                    filled: true,
                    fillColor: scheme.background.withValues(alpha: 0.35),
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
                  onPressed: _isSubmitting ? null : _submitReview,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: scheme.surfaceVariant,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(Translations.getText(context, 'submit_review')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
