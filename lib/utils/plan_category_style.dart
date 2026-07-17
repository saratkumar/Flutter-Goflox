import 'package:flutter/material.dart';

/// Maps a membership plan category name to a display icon/color. Known
/// categories keep the colors they had when the catalog was hardcoded;
/// any new category an admin creates gets a deterministic fallback so it
/// still looks consistent without needing to pick an icon manually.
class PlanCategoryStyle {
  final IconData icon;
  final Color color;
  final String description;
  const PlanCategoryStyle(this.icon, this.color, this.description);

  static const _known = {
    'Trials': PlanCategoryStyle(Icons.explore_outlined, Color(0xFF00D4AA),
        'A one-off, low-cost way to try a class before committing to a plan.'),
    'Drop-In': PlanCategoryStyle(Icons.bolt_outlined, Color(0xFF4FC3F7),
        'Pay per visit, no commitment — best if you attend occasionally.'),
    'Credits': PlanCategoryStyle(Icons.stars_outlined, Color(0xFFFFAB40),
        'A block of class credits to use at your own pace before they expire.'),
    'Monthly': PlanCategoryStyle(Icons.autorenew, Color(0xFFB388FF),
        'Ongoing access billed monthly — best if you train regularly.'),
    'Upfront': PlanCategoryStyle(Icons.workspace_premium_outlined,
        Color(0xFFFFD54F),
        'Pay once for a longer stretch of access, usually the best per-visit price.'),
    'Personal Training': PlanCategoryStyle(Icons.person_outline,
        Color(0xFFFF7043), '1-on-1 coaching sessions with a trainer.'),
    'Yoga': PlanCategoryStyle(Icons.self_improvement, Color(0xFF80CBC4),
        'Plans scoped to yoga classes specifically.'),
  };

  static const _fallbackPalette = [
    PlanCategoryStyle(Icons.category_outlined, Color(0xFF9E9E9E), ''),
    PlanCategoryStyle(Icons.local_offer_outlined, Color(0xFFEC407A), ''),
    PlanCategoryStyle(Icons.emoji_events_outlined, Color(0xFF26A69A), ''),
    PlanCategoryStyle(Icons.groups_outlined, Color(0xFF7986CB), ''),
  ];

  static PlanCategoryStyle of(String category) {
    final known = _known[category];
    if (known != null) return known;
    final idx = category.hashCode.abs() % _fallbackPalette.length;
    return _fallbackPalette[idx];
  }
}
