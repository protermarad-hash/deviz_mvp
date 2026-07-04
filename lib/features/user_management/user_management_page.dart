import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/auth/field_auth_models.dart';
import '../../core/cloud/firebase_bootstrap.dart';
import '../../core/cloud/firebase_collections.dart';
import 'user_management_service.dart';

/// Rand de utilizator citit din colectia Firestore `users`.
class _TenantUserRow {
  const _TenantUserRow({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    required this.active,
  });

  final String uid;
  final String name;
  final String email;
  final FieldUserRole role;
  final bool active;

  factory _TenantUserRow.fromDoc(String docId, Map<String, dynamic> data) {
    final firebaseUid = (data['firebase_uid'] ?? data['id'] ?? docId)
        .toString()
        .trim();
    return _TenantUserRow(
      uid: firebaseUid.isEmpty ? docId : firebaseUid,
      name: (data['name'] ?? '').toString().trim(),
      email: (data['email'] ?? '').toString().trim(),
      role: FieldUserRole.fromValue(data['role']?.toString()),
      active: data['active'] != false,
    );
  }
}

/// Ecran admin-only pentru gestionarea utilizatorilor (creare cont nou +
/// resetare parola) prin Cloud Functions. Accesul este restrictionat la
/// nivel de shell (allowedRoles: {UserRole.admin}).
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final UserManagementService _service = UserManagementService();

  bool _loading = true;
  String? _error;
  List<_TenantUserRow> _users = const <_TenantUserRow>[];

  @override
  void initState() {
    super.initState();
    FirebaseBootstrap.onlineNotifier.addListener(_onOnlineChanged);
    Future.microtask(_load);
  }

  @override
  void dispose() {
    FirebaseBootstrap.onlineNotifier.removeListener(_onOnlineChanged);
    super.dispose();
  }

  void _onOnlineChanged() {
    if (FirebaseBootstrap.onlineNotifier.value && _users.isEmpty && !_loading) {
      _load();
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    if (!FirebaseBootstrap.isInitialized) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Firebase nu este initializat. Verifica conexiunea.';
      });
      return;
    }
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection(FirebaseCollections.users)
          .get();
      final rows = snapshot.docs
          .map((doc) => _TenantUserRow.fromDoc(doc.id, doc.data()))
          .where((row) => row.email.isNotEmpty || row.name.isNotEmpty)
          .toList();
      rows.sort((a, b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      if (!mounted) return;
      setState(() {
        _users = rows;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Nu s-au putut incarca utilizatorii: $e';
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => _CreateUserDialog(service: _service),
    );
    if (created == true && mounted) {
      await _load();
    }
  }

  Future<void> _openPasswordDialog(_TenantUserRow user) async {
    await showDialog<bool>(
      context: context,
      builder: (_) => _ChangePasswordDialog(service: _service, user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestionare utilizatori'),
        actions: [
          IconButton(
            tooltip: 'Reincarca',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openCreateDialog,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Utilizator nou'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const SizedBox(height: 40),
          Icon(Icons.error_outline,
              size: 48, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 12),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          Center(
            child: FilledButton.icon(
              onPressed: _load,
              icon: const Icon(Icons.refresh),
              label: const Text('Reincarca'),
            ),
          ),
        ],
      );
    }
    if (_users.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 60),
          Center(child: Text('Nu exista utilizatori inregistrati.')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final user = _users[index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(
                (user.name.isNotEmpty ? user.name : user.email)
                    .characters
                    .first
                    .toUpperCase(),
              ),
            ),
            title: Text(user.name.isEmpty ? '(fara nume)' : user.name),
            subtitle: Text('${user.email}\nRol: ${user.role.label}'),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Chip(
                  label: Text(user.active ? 'Activ' : 'Inactiv'),
                  backgroundColor: user.active
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.grey.withValues(alpha: 0.2),
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Schimba parola',
                  icon: const Icon(Icons.password_outlined),
                  onPressed: () => _openPasswordDialog(user),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dialog creare utilizator nou.
class _CreateUserDialog extends StatefulWidget {
  const _CreateUserDialog({required this.service});

  final UserManagementService service;

  @override
  State<_CreateUserDialog> createState() => _CreateUserDialogState();
}

class _CreateUserDialogState extends State<_CreateUserDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  FieldUserRole _role = FieldUserRole.employee;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.createTenantUser(
        email: _emailController.text,
        password: _passwordController.text,
        name: _nameController.text,
        role: _role.value,
        phone: _phoneController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              'Utilizatorul ${_emailController.text.trim()} a fost creat.'),
        ),
      );
    } on UserManagementException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Eroare neasteptata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Utilizator nou'),
      content: SizedBox(
        width: 460,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Nume'),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Numele este obligatoriu.'
                      : null,
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) {
                    final value = (v ?? '').trim();
                    if (value.isEmpty) return 'Emailul este obligatoriu.';
                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value)) {
                      return 'Adresa de email nu este valida.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: 'Parola (min. 6)'),
                  validator: (v) {
                    final value = (v ?? '');
                    if (value.isEmpty) return 'Parola este obligatorie.';
                    if (value.length < 6) {
                      return 'Parola trebuie sa aiba minim 6 caractere.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<FieldUserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: const [
                    FieldUserRole.admin,
                    FieldUserRole.office,
                    FieldUserRole.teamLead,
                    FieldUserRole.employee,
                  ]
                      .map((role) => DropdownMenuItem<FieldUserRole>(
                            value: role,
                            child: Text(role.label),
                          ))
                      .toList(growable: false),
                  onChanged: _saving
                      ? null
                      : (value) {
                          if (value != null) setState(() => _role = value);
                        },
                ),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(labelText: 'Telefon (optional)'),
                ),
                if ((_error ?? '').isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Renunta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Creeaza'),
        ),
      ],
    );
  }
}

/// Dialog schimbare parola pentru un utilizator existent.
class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog({required this.service, required this.user});

  final UserManagementService service;
  final _TenantUserRow user;

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmController = TextEditingController();
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.adminSetUserPassword(
        targetUid: widget.user.uid,
        newPassword: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Parola pentru ${widget.user.email} a fost schimbata.'),
        ),
      );
    } on UserManagementException catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Eroare neasteptata: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Schimba parola (${widget.user.email})'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Parola noua (min. 6)'),
                validator: (v) {
                  final value = (v ?? '');
                  if (value.isEmpty) return 'Parola este obligatorie.';
                  if (value.length < 6) {
                    return 'Parola trebuie sa aiba minim 6 caractere.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Confirma parola'),
                validator: (v) {
                  if ((v ?? '') != _passwordController.text) {
                    return 'Parolele nu coincid.';
                  }
                  return null;
                },
              ),
              if ((_error ?? '').isNotEmpty) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _error!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Renunta'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Actualizeaza'),
        ),
      ],
    );
  }
}
