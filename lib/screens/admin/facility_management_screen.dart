import 'package:flutter/material.dart';
import '../../services/config_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_toast.dart';

class FacilityManagementScreen extends StatefulWidget {
  const FacilityManagementScreen({super.key});

  @override
  State<FacilityManagementScreen> createState() =>
      _FacilityManagementScreenState();
}

class _FacilityManagementScreenState
    extends State<FacilityManagementScreen> {
  late Future<List<Map<String, String>>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = ConfigService.getFacilities();
    });
  }

  Future<void> _openForm([Map<String, String>? existing]) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => _FacilityFormScreen(existing: existing)),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(Map<String, String> facility) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Delete "${facility['name']}"?',
            style: const TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text('This cannot be undone.',
            style: TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel',
                  style: TextStyle(color: AppColors.primary))),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                  foregroundColor: Colors.white),
              child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) {
      await ConfigService.deleteFacility(facility['id']!);
      if (mounted) {
        AppToast.success(context, 'Facility deleted');
        _reload();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Facilities')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Facility'),
      ),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final facilities = snap.data ?? [];
          if (facilities.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.place_outlined,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Text('No facilities yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Facility'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
            itemCount: facilities.length,
            itemBuilder: (_, i) => _FacilityCard(
              facility: facilities[i],
              onEdit: () => _openForm(facilities[i]),
              onDelete: () => _delete(facilities[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Facility card ─────────────────────────────────────────────────────────────

class _FacilityCard extends StatelessWidget {
  final Map<String, String> facility;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FacilityCard(
      {required this.facility, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4AA).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.place_outlined,
                color: Color(0xFF00D4AA), size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(facility['name'] ?? '',
                    style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
                const SizedBox(height: 3),
                Text(facility['address'] ?? '',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                if ((facility['description'] ?? '').isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(facility['description']!,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textMuted)),
                ],
              ],
            ),
          ),
          Column(
            children: [
              IconButton(
                icon: const Icon(Icons.edit_outlined,
                    color: AppColors.primary, size: 20),
                onPressed: onEdit,
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.error, size: 20),
                onPressed: onDelete,
                tooltip: 'Delete',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Facility form screen ──────────────────────────────────────────────────────

class _FacilityFormScreen extends StatefulWidget {
  final Map<String, String>? existing;
  const _FacilityFormScreen({this.existing});

  @override
  State<_FacilityFormScreen> createState() => _FacilityFormScreenState();
}

class _FacilityFormScreenState extends State<_FacilityFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _desc;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.existing?['name'] ?? '');
    _address = TextEditingController(text: widget.existing?['address'] ?? '');
    _desc =
        TextEditingController(text: widget.existing?['description'] ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (widget.existing == null) {
        await ConfigService.addFacility(
          _name.text.trim(),
          _address.text.trim(),
          _desc.text.trim(),
        );
      } else {
        await ConfigService.updateFacility(
          widget.existing!['id']!,
          _name.text.trim(),
          _address.text.trim(),
          _desc.text.trim(),
        );
      }
      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(context,
            widget.existing == null ? 'Facility added' : 'Facility updated');
      }
    } catch (err) {
      setState(() => _saving = false);
      if (mounted) AppToast.error(context, err.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: Text(
              widget.existing == null ? 'New Facility' : 'Edit Facility')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_name, 'Facility Name', required: true),
            const SizedBox(height: 12),
            _field(_address, 'Address', required: true),
            const SizedBox(height: 12),
            _field(_desc, 'Description (optional)', maxLines: 3),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(widget.existing == null
                      ? 'Add Facility'
                      : 'Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label,
      {bool required = false, int maxLines = 1}) {
    return TextFormField(
      controller: ctrl,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }
}
