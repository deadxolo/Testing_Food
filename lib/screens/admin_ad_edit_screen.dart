import 'package:flutter/material.dart';
import '../widgets/glass_card.dart';

import '../models/ad.dart';
import '../services/ads_service.dart';
import '../theme.dart';

/// Create / edit a single promo ad. Title + body required; CTA, image URL and
/// schedule optional. Saves to `ads/{id}` via [AdsService].
class AdminAdEditScreen extends StatefulWidget {
  const AdminAdEditScreen({super.key, this.ad});
  final Ad? ad;

  @override
  State<AdminAdEditScreen> createState() => _AdminAdEditScreenState();
}

class _AdminAdEditScreenState extends State<AdminAdEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _body;
  late final TextEditingController _image;
  late final TextEditingController _ctaLabel;
  late final TextEditingController _ctaUrl;
  late final TextEditingController _priority;
  bool _enabled = true;
  DateTime? _startsAt;
  DateTime? _endsAt;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final a = widget.ad;
    _title = TextEditingController(text: a?.title ?? '');
    _body = TextEditingController(text: a?.body ?? '');
    _image = TextEditingController(text: a?.imageUrl ?? '');
    _ctaLabel = TextEditingController(text: a?.ctaLabel ?? '');
    _ctaUrl = TextEditingController(text: a?.ctaUrl ?? '');
    _priority = TextEditingController(text: '${a?.priority ?? 0}');
    _enabled = a?.enabled ?? true;
    _startsAt = a?.startsAt;
    _endsAt = a?.endsAt;
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _image.dispose();
    _ctaLabel.dispose();
    _ctaUrl.dispose();
    _priority.dispose();
    super.dispose();
  }

  bool _empty(String s) => s.trim().isEmpty;

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final ad = Ad(
      id: widget.ad?.id ?? '',
      title: _title.text.trim(),
      body: _body.text.trim(),
      imageUrl: _empty(_image.text) ? null : _image.text.trim(),
      ctaLabel: _empty(_ctaLabel.text) ? null : _ctaLabel.text.trim(),
      ctaUrl: _empty(_ctaUrl.text) ? null : _ctaUrl.text.trim(),
      enabled: _enabled,
      priority: int.tryParse(_priority.text.trim()) ?? 0,
      startsAt: _startsAt,
      endsAt: _endsAt,
    );
    try {
      await AdsService.instance.save(ad);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(widget.ad == null ? 'Ad created' : 'Ad saved')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Save failed: $e')));
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final initial = (start ? _startsAt : _endsAt) ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
    );
    if (picked == null) return;
    setState(() {
      if (start) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.ad == null ? 'New ad' : 'Edit ad'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Title',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Title is required' : null,
              maxLength: 60,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _body,
              decoration: const InputDecoration(
                labelText: 'Body',
                border: OutlineInputBorder(),
                hintText: 'One or two sentences — keep it punchy.',
              ),
              maxLines: 3,
              maxLength: 240,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Body is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _image,
              decoration: const InputDecoration(
                labelText: 'Image URL (optional)',
                border: OutlineInputBorder(),
                hintText: 'https://… (jpeg / png / webp)',
              ),
              keyboardType: TextInputType.url,
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: _ctaLabel,
                  decoration: const InputDecoration(
                    labelText: 'CTA label',
                    border: OutlineInputBorder(),
                    hintText: 'Learn more',
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 5,
                child: TextFormField(
                  controller: _ctaUrl,
                  decoration: const InputDecoration(
                    labelText: 'CTA URL',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.url,
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: TextFormField(
                  controller: _priority,
                  decoration: const InputDecoration(
                    labelText: 'Priority',
                    border: OutlineInputBorder(),
                    helperText: 'Higher = shown first',
                  ),
                  keyboardType: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: _enabled,
                  onChanged: (v) => setState(() => _enabled = v),
                  title: Text(_enabled ? 'Enabled' : 'Disabled'),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Schedule (optional)',
                          style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 6),
                      _DateRow(
                        label: 'Starts',
                        date: _startsAt,
                        onTap: () => _pickDate(start: true),
                        onClear: () => setState(() => _startsAt = null),
                      ),
                      _DateRow(
                        label: 'Ends',
                        date: _endsAt,
                        onTap: () => _pickDate(start: false),
                        onClear: () => setState(() => _endsAt = null),
                      ),
                    ]),
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.save_rounded),
              label: Text(widget.ad == null ? 'Create ad' : 'Save changes'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DateRow extends StatelessWidget {
  const _DateRow({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(children: [
        SizedBox(
          width: 64,
          child: Text(label,
              style: const TextStyle(
                  color: AppColors.inkSoft, fontWeight: FontWeight.w600)),
        ),
        Expanded(
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black.withValues(alpha: 0.12)),
              ),
              child: Text(
                date == null
                    ? 'Tap to pick…'
                    : '${date!.year.toString().padLeft(4, "0")}-${date!.month.toString().padLeft(2, "0")}-${date!.day.toString().padLeft(2, "0")}',
                style: TextStyle(
                    color: date == null ? Colors.black45 : Colors.black87),
              ),
            ),
          ),
        ),
        if (date != null)
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: onClear,
            color: Colors.black38,
          ),
      ]),
    );
  }
}
