import 'package:flutter/material.dart';
import '../../models/class_model.dart';
import '../../models/user_model.dart';
import '../../services/config_service.dart';
import '../../services/google_sheet_service.dart';
import '../../services/user_service.dart';
import '../../utils/app_colors.dart';
import '../../utils/app_toast.dart';

class ClassManagementScreen extends StatefulWidget {
  const ClassManagementScreen({super.key});

  @override
  State<ClassManagementScreen> createState() => _ClassManagementScreenState();
}

class _ClassManagementScreenState extends State<ClassManagementScreen> {
  late Future<List<ClassModel>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    if (!mounted) return;
    setState(() {
      _future = GoogleSheetService.getClasses();
    });
  }

  Future<void> _openForm(ClassModel? existing) async {
    final saved = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => _ClassFormScreen(existing: existing)),
    );
    if (saved == true && mounted) _reload();
  }

  Future<void> _delete(ClassModel cls) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Delete Class?',
            style: TextStyle(
                color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
            'This will remove the class from the sheet. Existing bookings are unaffected.',
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
      final key = '${cls.day}|${cls.mode}|${cls.startTime}';
      await ConfigService.deleteClass(key);
      if (mounted) AppToast.success(context, 'Class deleted');
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(null),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Class'),
      ),
      body: FutureBuilder<List<ClassModel>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
                child: CircularProgressIndicator(color: AppColors.primary));
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final classes = snap.data ?? [];
          if (classes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.fitness_center,
                      size: 56, color: AppColors.textMuted),
                  const SizedBox(height: 14),
                  const Text('No classes yet',
                      style: TextStyle(
                          color: AppColors.textSecondary, fontSize: 15)),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _openForm(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Class'),
                  ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(14),
            itemCount: classes.length,
            itemBuilder: (context, i) => _ClassCard(
              cls: classes[i],
              onEdit: () => _openForm(classes[i]),
              onDelete: () => _delete(classes[i]),
            ),
          );
        },
      ),
    );
  }
}

// ── Class card ────────────────────────────────────────────────────────────────

class _ClassCard extends StatelessWidget {
  final ClassModel cls;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ClassCard(
      {required this.cls, required this.onEdit, required this.onDelete});

  static const _abbr = {
    'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
    'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
  };
  static const _ordered = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];

  static String _formatDay(String day, String occurrence) {
    if (occurrence == 'daily') return 'Every day';
    if (occurrence == 'once') return 'Once';
    if (occurrence == 'monthly') return 'Monthly';
    final days = day.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toSet();
    if (days.length == 7) { return 'Every day'; }
    if (days.length == 5 &&
        !days.contains('Saturday') && !days.contains('Sunday')) { return 'Weekdays'; }
    if (days.length == 2 &&
        days.contains('Saturday') && days.contains('Sunday')) { return 'Weekends'; }
    final sorted = _ordered.where(days.contains).map((d) => _abbr[d] ?? d).toList();
    return sorted.isEmpty ? day : sorted.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
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
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(cls.mode,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(cls.type,
                          style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                    '${_formatDay(cls.day, cls.occurrence)} · ${cls.startTime} · ${cls.duration} · Cap: ${cls.groupSize}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                Text('${cls.location} · ${cls.coach}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textMuted)),
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

// ── Class form screen ─────────────────────────────────────────────────────────

class _ClassFormScreen extends StatefulWidget {
  final ClassModel? existing;
  const _ClassFormScreen({this.existing});

  @override
  State<_ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<_ClassFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _mode;
  late final TextEditingController _location;
  late final TextEditingController _detailLocation;
  late final TextEditingController _groupSize;
  late final TextEditingController _duration;
  late final TextEditingController _startTime;
  late final TextEditingController _image;

  Set<String> _selectedDays = {'Monday'};
  String _type = 'Fitness';
  String _occurrence = 'weekly';
  DateTime? _specificDate;
  bool _saving = false;

  // Dropdowns loaded async
  List<Map<String, String>> _facilities = [];
  List<UserModel> _trainers = [];
  List<Map<String, String>> _typeItems = [];
  Map<String, String> _typeImages = {};
  List<String> _dynamicTypes = [];
  String? _selectedFacilityId;
  String? _selectedCoach;
  bool _loadingData = true;
  // true while image was auto-filled from type mapping (allows override)
  bool _imageAutoSet = false;

  static const _weekdayOrder = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday'
  ];
  // Fallback types used only when the Types sheet is empty
  static const _fallbackTypes = [
    'Fitness', 'Boxing', 'Yoga', 'Group PT', 'Muay Thai', 'Kids'
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _mode = TextEditingController(text: e?.mode ?? '');
    _location = TextEditingController(text: e?.location ?? '');
    _detailLocation = TextEditingController(text: e?.detailLocation ?? '');
    _groupSize = TextEditingController(text: e?.groupSize ?? '');
    _duration = TextEditingController(text: e?.duration ?? '');
    _startTime = TextEditingController(text: e?.startTime ?? '');
    _image = TextEditingController(text: e?.image ?? '');
    _type = e?.type ?? 'Fitness';
    _occurrence = e?.occurrence ?? 'weekly';
    if (e != null && e.day.isNotEmpty) {
      final parsed = e.day.split(',').map((d) => d.trim()).where((d) => d.isNotEmpty).toSet();
      _selectedDays = parsed.isEmpty ? {'Monday'} : parsed;
    }
    _selectedFacilityId = e?.facilityId;
    _selectedCoach = (e?.coach.isNotEmpty ?? false) ? e!.coach : null;
    if (e?.specificDate != null) {
      final parts = e!.specificDate!.split('-');
      if (parts.length == 3) {
        _specificDate = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
      }
    }
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final results = await Future.wait([
        ConfigService.getFacilities(),
        UserService.getUsersByRole('trainer'),
        ConfigService.getTypes(),
      ]);
      if (!mounted) return;
      setState(() {
        _facilities = results[0] as List<Map<String, String>>;
        _trainers = results[1] as List<UserModel>;
        _typeItems = results[2] as List<Map<String, String>>;
        _typeImages = Map.fromEntries(
          _typeItems.map((t) => MapEntry(t['name'] ?? '', t['imageUrl'] ?? '')),
        );
        _dynamicTypes = _typeItems.map((t) => t['name'] ?? '').toList();
        if (_dynamicTypes.isEmpty) _dynamicTypes = List.of(_fallbackTypes);
        // Ensure current _type is valid in the loaded list
        if (!_dynamicTypes.contains(_type) && _dynamicTypes.isNotEmpty) {
          _type = _dynamicTypes.first;
        }
        _loadingData = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _dynamicTypes = List.of(_fallbackTypes);
          _loadingData = false;
        });
      }
    }
  }

  @override
  void dispose() {
    for (final c in [
      _mode, _location, _detailLocation,
      _groupSize, _duration, _startTime, _image
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTypeChanged(String? v) {
    if (v == null) return;
    setState(() {
      _type = v;
      final url = _typeImages[v];
      if (url != null && url.isNotEmpty) {
        _image.text = url;
        _imageAutoSet = true;
      } else if (_imageAutoSet) {
        // Clear previously auto-set image if new type has no mapping
        _image.text = '';
        _imageAutoSet = false;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    // _selectedCoach is set from Autocomplete onSelected or onChanged (typing)
    final coachName = (_selectedCoach ?? '').trim();
    if (coachName.isEmpty) {
      AppToast.error(context, 'Please enter a coach name');
      return;
    }
    // Build day string based on occurrence
    final String dayValue;
    if (_occurrence == 'weekly') {
      final sorted = _weekdayOrder.where(_selectedDays.contains).toList();
      if (sorted.isEmpty) {
        AppToast.error(context, 'Select at least one day');
        return;
      }
      dayValue = sorted.join(',');
    } else if (_occurrence == 'daily') {
      dayValue = 'Daily';
    } else {
      dayValue = '';
    }

    setState(() => _saving = true);

    // Resolve facility name for location label if a facility is selected
    String locationLabel = _location.text.trim();
    String detailLabel = _detailLocation.text.trim();
    if (_selectedFacilityId != null && _facilities.isNotEmpty) {
      final fac = _facilities.firstWhere(
          (f) => f['id'] == _selectedFacilityId,
          orElse: () => {});
      if (fac.isNotEmpty) {
        if (locationLabel.isEmpty) locationLabel = fac['name'] ?? locationLabel;
        if (detailLabel.isEmpty) detailLabel = fac['address'] ?? detailLabel;
      }
    }

    final fields = {
      'day': dayValue,
      'mode': _mode.text.trim(),
      'coach': coachName,
      'location': locationLabel,
      'groupSize': _groupSize.text.trim(),
      'duration': _duration.text.trim(),
      'detailLocation': detailLabel,
      'startTime': _startTime.text.trim(),
      'type': _type,
      'image': _image.text.trim(),
      'occurrence': _occurrence,
      'facilityId': _selectedFacilityId ?? '',
      'specificDate': _specificDate != null
          ? '${_specificDate!.year}-'
              '${_specificDate!.month.toString().padLeft(2, '0')}-'
              '${_specificDate!.day.toString().padLeft(2, '0')}'
          : '',
    };

    try {
      if (widget.existing == null) {
        await ConfigService.addClass(fields);
      } else {
        final e = widget.existing!;
        final originalKey = '${e.day}|${e.mode}|${e.startTime}';
        await ConfigService.updateClass(originalKey, fields);
      }
      if (mounted) {
        Navigator.pop(context, true);
        AppToast.success(context,
            widget.existing == null ? 'Class added to sheet' : 'Class updated');
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
              widget.existing == null ? 'New Class' : 'Edit Class')),
      body: _loadingData
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _field(_mode, 'Class Name', required: true),
                  const SizedBox(height: 12),
                  // Type dropdown — also auto-fills image
                  _dropdown('Type', _dynamicTypes, _type, _onTypeChanged),
                  const SizedBox(height: 12),
                  // Facility dropdown from Google Sheet
                  _facilityDropdown(),
                  const SizedBox(height: 12),
                  // Coach autocomplete from Firestore trainers (free-text allowed)
                  _coachField(),
                  const SizedBox(height: 12),
                  _field(_startTime, 'Start Time (e.g. 6:30 AM)',
                      required: true),
                  const SizedBox(height: 12),
                  _field(_duration, 'Duration (e.g. 60 mins)', required: true),
                  const SizedBox(height: 12),
                  _field(_groupSize, 'Capacity',
                      required: true,
                      keyboardType: TextInputType.number),
                  const SizedBox(height: 12),
                  _field(_location, 'Short Location Label (optional — auto-fills from facility)'),
                  const SizedBox(height: 12),
                  _field(_detailLocation,
                      'Detail Address (optional — auto-fills from facility)'),
                  const SizedBox(height: 12),
                  // Image — shows auto-set hint when mapped from type
                  _imageField(),
                  const SizedBox(height: 16),
                  const Text('Occurrence',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary)),
                  const SizedBox(height: 8),
                  _OccurrencePicker(
                    value: _occurrence,
                    onChanged: (v) => setState(() {
                      _occurrence = v;
                      if (v != 'once' && v != 'monthly') _specificDate = null;
                    }),
                  ),
                  const SizedBox(height: 12),
                  if (_occurrence == 'weekly')
                    _WeekDayPicker(
                      selected: _selectedDays,
                      onChanged: (days) =>
                          setState(() => _selectedDays = days),
                    )
                  else if (_occurrence == 'daily')
                    const Row(
                      children: [
                        Icon(Icons.info_outline,
                            size: 14, color: AppColors.textMuted),
                        SizedBox(width: 6),
                        Text('Runs every day',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textMuted)),
                      ],
                    )
                  else
                    _datePicker(),
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
                            ? 'Create Class'
                            : 'Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _facilityDropdown() {
    if (_facilities.isEmpty) {
      return TextFormField(
        enabled: false,
        decoration: InputDecoration(
          labelText: 'Facility (add Facilities tab to Google Sheet)',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon:
              const Icon(Icons.info_outline, size: 16, color: AppColors.textMuted),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: _selectedFacilityId,
      decoration: InputDecoration(
        labelText: 'Facility',
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: [
        const DropdownMenuItem(value: null, child: Text('— None —')),
        ..._facilities.map((f) => DropdownMenuItem(
              value: f['id'],
              child: Text(f['name'] ?? f['id'] ?? ''),
            )),
      ],
      onChanged: (v) {
        setState(() => _selectedFacilityId = v);
        if (v == null) return;
        final fac = _facilities.firstWhere(
            (f) => f['id'] == v, orElse: () => {});
        if (fac.isNotEmpty) {
          if (_location.text.trim().isEmpty) {
            _location.text = fac['name'] ?? '';
          }
          if (_detailLocation.text.trim().isEmpty) {
            _detailLocation.text = fac['address'] ?? '';
          }
        }
      },
    );
  }

  // Autocomplete that suggests registered trainers but allows typing any name freely.
  // This works even when no trainers are in Firestore yet.
  Widget _coachField() {
    final trainerNames =
        _trainers.map((t) => t.name).where((n) => n.isNotEmpty).toList();

    return Autocomplete<String>(
      initialValue: TextEditingValue(text: _selectedCoach ?? ''),
      optionsBuilder: (TextEditingValue v) {
        final q = v.text.toLowerCase();
        if (q.isEmpty) return trainerNames;
        return trainerNames.where((n) => n.toLowerCase().contains(q));
      },
      onSelected: (name) => setState(() => _selectedCoach = name),
      fieldViewBuilder: (ctx, ctrl, focusNode, onSubmitted) {
        // Pre-fill when editing an existing class
        if (ctrl.text.isEmpty && (_selectedCoach?.isNotEmpty ?? false)) {
          ctrl.text = _selectedCoach!;
        }
        return TextFormField(
          controller: ctrl,
          focusNode: focusNode,
          onChanged: (v) => _selectedCoach = v.trim(),
          decoration: InputDecoration(
            labelText: 'Coach',
            hintText: trainerNames.isEmpty
                ? 'Type coach name (must match Classes sheet)'
                : 'Select from registered trainers or type',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: trainerNames.isNotEmpty
                ? const Icon(Icons.arrow_drop_down,
                    color: AppColors.textMuted)
                : const Tooltip(
                    message:
                        'No trainers in Firestore yet — type a name manually',
                    child: Icon(Icons.info_outline,
                        size: 18, color: AppColors.textMuted),
                  ),
          ),
          validator: (v) =>
              (v == null || v.trim().isEmpty) ? 'Coach name is required' : null,
        );
      },
      optionsViewBuilder: (ctx, onSelected, options) => Align(
        alignment: Alignment.topLeft,
        child: Material(
          elevation: 6,
          color: AppColors.card,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: 220, maxWidth: 380),
            child: ListView.builder(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: options.length,
              itemBuilder: (_, i) {
                final name = options.elementAt(i);
                return ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        const Color(0xFF00D4AA).withValues(alpha: 0.15),
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF00D4AA),
                          fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(name,
                      style:
                          const TextStyle(color: AppColors.textPrimary)),
                  subtitle: const Text('Registered trainer',
                      style: TextStyle(
                          fontSize: 10, color: AppColors.textMuted)),
                  onTap: () => onSelected(name),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _imageField() {
    return Stack(
      children: [
        TextFormField(
          controller: _image,
          onChanged: (_) => setState(() => _imageAutoSet = false),
          decoration: InputDecoration(
            labelText: 'Image URL',
            hintText: _typeImages.containsKey(_type)
                ? 'Auto-filled from type — tap to override'
                : 'https://...',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            suffixIcon: _imageAutoSet
                ? const Tooltip(
                    message: 'Auto-set from type mapping',
                    child: Icon(Icons.auto_awesome,
                        size: 16, color: AppColors.primary),
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Widget _datePicker() {
    return GestureDetector(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _specificDate ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
          builder: (context, child) => Theme(
            data: Theme.of(context).copyWith(
              colorScheme: const ColorScheme.light(
                primary: AppColors.primary,
              ),
            ),
            child: child!,
          ),
        );
        if (picked != null) setState(() => _specificDate = picked);
      },
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(
              color: _specificDate == null
                  ? AppColors.error
                  : AppColors.divider),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.textMuted),
            const SizedBox(width: 10),
            Text(
              _specificDate == null
                  ? _occurrence == 'once'
                      ? 'Pick the class date *'
                      : 'Pick reference date (sets week-of-month) *'
                  : '${_specificDate!.day}/'
                      '${_specificDate!.month}/'
                      '${_specificDate!.year}',
              style: TextStyle(
                color: _specificDate == null
                    ? AppColors.textMuted
                    : AppColors.textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController ctrl,
    String label, {
    bool required = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: ctrl,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      validator: required
          ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
          : null,
    );
  }

  Widget _dropdown(String label, List<String> items, String value,
      ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      items: items
          .map((s) => DropdownMenuItem(value: s, child: Text(s)))
          .toList(),
      onChanged: onChanged,
    );
  }
}

// ── Week-day multi-selector ───────────────────────────────────────────────────

class _WeekDayPicker extends StatelessWidget {
  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  const _WeekDayPicker({required this.selected, required this.onChanged});

  static const _full = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];
  static const _abbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Repeat on',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        Row(
          children: List.generate(7, (i) {
            final day = _full[i];
            final lbl = _abbr[i];
            final sel = selected.contains(day);
            return Expanded(
              child: GestureDetector(
                onTap: () {
                  final next = Set<String>.from(selected);
                  if (sel) {
                    if (next.length > 1) next.remove(day);
                  } else {
                    next.add(day);
                  }
                  onChanged(next);
                },
                child: Container(
                  margin: const EdgeInsets.only(right: 4),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.primary : AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: sel
                          ? AppColors.primary
                          : AppColors.divider,
                      width: sel ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    lbl,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        if (selected.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 4),
            child: Text(
              'Select at least one day',
              style: TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ),
      ],
    );
  }
}

// ── Occurrence picker ─────────────────────────────────────────────────────────

class _OccurrencePicker extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _OccurrencePicker(
      {required this.value, required this.onChanged});

  static const _options = [
    ('weekly', Icons.repeat, 'Weekly'),
    ('daily', Icons.repeat_one, 'Daily'),
    ('monthly', Icons.calendar_view_month, 'Monthly'),
    ('once', Icons.looks_one_outlined, 'Once'),
  ];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: _options.map((opt) {
        final (key, icon, label) = opt;
        final selected = value == key;
        return Expanded(
          child: GestureDetector(
            onTap: () => onChanged(key),
            child: Container(
              margin: const EdgeInsets.only(right: 6),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: selected
                    ? AppColors.primary.withValues(alpha: 0.12)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : AppColors.divider,
                  width: selected ? 1.5 : 1,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon,
                      size: 18,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textMuted),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: selected
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
