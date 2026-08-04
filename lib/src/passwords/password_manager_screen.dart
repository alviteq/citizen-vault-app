import 'dart:async';
import 'dart:math';

import 'package:citizen_vault_app/src/ingestion/ingestion_ui_controller.dart';
import 'package:citizen_vault_app/src/vault/biometric_authenticator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:vault_domain/vault_domain.dart';

/// Encrypted password records stored inside the unlocked OwnKeep vault.
final class PasswordManagerScreen extends StatefulWidget {
  /// Creates the password manager.
  const PasswordManagerScreen({required this.controller, super.key});

  /// Unlocked vault controller.
  final IngestionUiController controller;

  @override
  State<PasswordManagerScreen> createState() => _PasswordManagerScreenState();
}

final class _PasswordManagerScreenState extends State<PasswordManagerScreen> {
  static const _subtype = 'PASSWORD_ENTRY';
  static const _usernameKey = 'PASSWORD_USERNAME';
  static const _passwordKey = 'PASSWORD_SECRET';
  static const _websiteKey = 'PASSWORD_WEBSITE';
  static const _notesKey = 'PASSWORD_NOTES';

  final _search = TextEditingController();
  var _loading = true;
  var _entries = <_PasswordEntry>[];

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() => _loading = true);
    final entries = <_PasswordEntry>[];
    for (final entity in widget.controller.entities.where(
      (item) =>
          item.type == LifeEntityType.account &&
          item.subtype == _subtype &&
          item.status == LifeEntityStatus.active,
    )) {
      final attributes = await widget.controller.entityAttributes(entity.id);
      final values = <String, String>{
        for (final attribute in attributes)
          if (attribute.value.type == ClaimValueType.string ||
              attribute.value.type == ClaimValueType.uri)
            attribute.key: attribute.value.stringValue,
      };
      entries.add(
        _PasswordEntry(
          entity: entity,
          username: values[_usernameKey] ?? '',
          password: values[_passwordKey] ?? '',
          website: values[_websiteKey] ?? '',
          notes: values[_notesKey] ?? '',
        ),
      );
    }
    entries.sort(
      (left, right) => left.title.toLowerCase().compareTo(
        right.title.toLowerCase(),
      ),
    );
    if (mounted) {
      setState(() {
        _entries = entries;
        _loading = false;
      });
    }
  }

  Future<bool> _authorize(String reason) async {
    final authenticator = PlatformBiometricAuthenticator();
    if (await authenticator.isAvailable()) {
      return authenticator.authenticate();
    }
    if (!mounted) return false;
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reveal protected password?'),
            content: Text(
              '$reason\n\nBiometrics are unavailable. Continue because the '
              'encrypted vault is already unlocked?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Continue'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _copy(_PasswordEntry entry) async {
    if (!await _authorize('Copy ${entry.title} to the clipboard.')) return;
    await Clipboard.setData(ClipboardData(text: entry.password));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Password copied. It clears in 30 seconds.')),
    );
    Timer(const Duration(seconds: 30), () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == entry.password) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  Future<void> _reveal(_PasswordEntry entry) async {
    if (!await _authorize('Reveal ${entry.title}.') || !mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(entry.title),
        content: SelectableText(
          entry.password,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit([_PasswordEntry? entry]) async {
    if (entry != null &&
        !await _authorize('Edit the protected ${entry.title} password.')) {
      return;
    }
    if (!mounted) return;
    final draft = await showDialog<_PasswordDraft>(
      context: context,
      builder: (context) => _PasswordEditor(entry: entry),
    );
    if (draft == null) return;
    if (entry == null) {
      final id = await widget.controller.createEntity(
        type: LifeEntityType.account,
        displayName: draft.title,
        subtype: _subtype,
      );
      if (id == null) return;
      await _saveAttributes(id, draft);
    } else {
      await widget.controller.updateEntity(
        entityId: entry.entity.id,
        displayName: draft.title,
        subtype: _subtype,
      );
      await _saveAttributes(entry.entity.id, draft);
    }
    await _load();
  }

  Future<void> _saveAttributes(String entityId, _PasswordDraft draft) async {
    await widget.controller.upsertEntityAttribute(
      entityId: entityId,
      key: _usernameKey,
      value: ClaimValue.string(draft.username),
    );
    await widget.controller.upsertEntityAttribute(
      entityId: entityId,
      key: _passwordKey,
      value: ClaimValue.string(draft.password),
    );
    await widget.controller.upsertEntityAttribute(
      entityId: entityId,
      key: _websiteKey,
      value: ClaimValue.uri(draft.website),
    );
    await widget.controller.upsertEntityAttribute(
      entityId: entityId,
      key: _notesKey,
      value: ClaimValue.string(draft.notes),
    );
  }

  Future<void> _archive(_PasswordEntry entry) async {
    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Archive password?'),
            content: Text('${entry.title} will be removed from this list.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Archive'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.controller.setEntityArchived(entry.entity.id, true);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final visible = _entries.where((entry) {
      if (query.isEmpty) return true;
      return entry.title.toLowerCase().contains(query) ||
          entry.username.toLowerCase().contains(query) ||
          entry.website.toLowerCase().contains(query);
    }).toList(growable: false);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Password Manager'),
        actions: [
          IconButton(
            tooltip: 'Add password',
            onPressed: () => _edit(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Add password'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search title, website, or username',
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : visible.isEmpty
                ? const _EmptyPasswords()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
                    itemCount: visible.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final entry = visible[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.key_outlined),
                          ),
                          title: Text(entry.title),
                          subtitle: Text(
                            [
                              entry.username,
                              entry.website,
                            ].where((value) => value.isNotEmpty).join(' · '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          onTap: () => _edit(entry),
                          trailing: Wrap(
                            children: [
                              IconButton(
                                tooltip: 'Reveal',
                                onPressed: () => _reveal(entry),
                                icon: const Icon(Icons.visibility_outlined),
                              ),
                              IconButton(
                                tooltip: 'Copy password',
                                onPressed: () => _copy(entry),
                                icon: const Icon(Icons.copy_outlined),
                              ),
                              PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') unawaited(_edit(entry));
                                  if (value == 'archive') {
                                    unawaited(_archive(entry));
                                  }
                                },
                                itemBuilder: (_) => const [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'archive',
                                    child: Text('Archive'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

final class _PasswordEditor extends StatefulWidget {
  const _PasswordEditor({this.entry});

  final _PasswordEntry? entry;

  @override
  State<_PasswordEditor> createState() => _PasswordEditorState();
}

final class _PasswordEditorState extends State<_PasswordEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _username;
  late final TextEditingController _password;
  late final TextEditingController _website;
  late final TextEditingController _notes;
  var _visible = false;

  @override
  void initState() {
    super.initState();
    final entry = widget.entry;
    _title = TextEditingController(text: entry?.title);
    _username = TextEditingController(text: entry?.username);
    _password = TextEditingController(text: entry?.password);
    _website = TextEditingController(text: entry?.website);
    _notes = TextEditingController(text: entry?.notes);
  }

  @override
  void dispose() {
    _title.dispose();
    _username.dispose();
    _password.dispose();
    _website.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _generate() {
    const chars =
        'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#%^&*_-+=';
    final random = Random.secure();
    _password.text = List.generate(
      20,
      (_) => chars[random.nextInt(chars.length)],
    ).join();
    setState(() => _visible = true);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.pop(
      context,
      _PasswordDraft(
        title: _title.text.trim(),
        username: _username.text.trim(),
        password: _password.text,
        website: _website.text.trim(),
        notes: _notes.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.entry == null ? 'Add password' : 'Edit password'),
    content: SizedBox(
      width: 480,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _title,
                autofocus: true,
                decoration: const InputDecoration(labelText: 'Title'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Enter a title.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _website,
                decoration: const InputDecoration(labelText: 'Website or app'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _username,
                decoration: const InputDecoration(
                  labelText: 'Username or email',
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _password,
                obscureText: !_visible,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: 'Password',
                  suffixIcon: Wrap(
                    children: [
                      IconButton(
                        tooltip: 'Generate strong password',
                        onPressed: _generate,
                        icon: const Icon(Icons.auto_awesome),
                      ),
                      IconButton(
                        tooltip: _visible ? 'Hide' : 'Show',
                        onPressed: () => setState(() => _visible = !_visible),
                        icon: Icon(
                          _visible ? Icons.visibility_off : Icons.visibility,
                        ),
                      ),
                    ],
                  ),
                ),
                validator: (value) => value == null || value.isEmpty
                    ? 'Enter or generate a password.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                minLines: 2,
                maxLines: 5,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: const InputDecoration(labelText: 'Private notes'),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(onPressed: _save, child: const Text('Save')),
    ],
  );
}

final class _EmptyPasswords extends StatelessWidget {
  const _EmptyPasswords();

  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(
      padding: EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.password_outlined, size: 64),
          SizedBox(height: 16),
          Text(
            'No saved passwords',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 8),
          Text(
            'Passwords stay inside your encrypted OwnKeep vault.',
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}

final class _PasswordEntry {
  const _PasswordEntry({
    required this.entity,
    required this.username,
    required this.password,
    required this.website,
    required this.notes,
  });

  final LifeEntity entity;
  final String username;
  final String password;
  final String website;
  final String notes;

  String get title => entity.displayName;
}

final class _PasswordDraft {
  const _PasswordDraft({
    required this.title,
    required this.username,
    required this.password,
    required this.website,
    required this.notes,
  });

  final String title;
  final String username;
  final String password;
  final String website;
  final String notes;
}
