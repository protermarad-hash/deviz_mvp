import 'package:flutter/material.dart';

import '../../core/auth/field_auth_service.dart';
import '../../core/auth/field_local_auth_repository.dart';

/// Ecran afișat după autentificare când parola locală trebuie schimbată
/// (ex. contul de dezvoltare `admin@local.test` cu parola implicită pe un
/// dispozitiv cu o versiune mai veche). Nu blochează accesul legitim: parola
/// curentă rămâne valabilă până la schimbare, iar „Deconectare” este mereu
/// disponibilă.
class ForcedPasswordChangePage extends StatefulWidget {
  const ForcedPasswordChangePage({super.key, required this.authService});

  final FieldAuthService authService;

  @override
  State<ForcedPasswordChangePage> createState() =>
      _ForcedPasswordChangePageState();
}

class _ForcedPasswordChangePageState extends State<ForcedPasswordChangePage> {
  final _formKey = GlobalKey<FormState>();
  final _currentController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();

  @override
  void dispose() {
    _currentController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await widget.authService.changePassword(
      currentPassword: _currentController.text,
      newPassword: _newController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final service = widget.authService;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Schimbă parola',
                        style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'Contul ${service.userEmail ?? ''} folosește o parolă '
                      'implicită. Pentru siguranță, alege o parolă nouă '
                      'înainte de a continua.',
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _currentController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Parola curentă'),
                      validator: (v) => (v ?? '').isEmpty
                          ? 'Completează parola curentă'
                          : null,
                    ),
                    TextFormField(
                      controller: _newController,
                      obscureText: true,
                      decoration:
                          const InputDecoration(labelText: 'Parola nouă'),
                      validator: (v) => (v ?? '').length <
                              FieldLocalAuthRepository.minPasswordLength
                          ? 'Minimum ${FieldLocalAuthRepository.minPasswordLength} caractere'
                          : null,
                    ),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: true,
                      decoration: const InputDecoration(
                          labelText: 'Confirmă parola nouă'),
                      validator: (v) => v != _newController.text
                          ? 'Parolele nu coincid'
                          : null,
                    ),
                    if (service.lastError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        service.lastError!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: service.isLoading ? null : _submit,
                      child: service.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Schimbă parola'),
                    ),
                    TextButton(
                      onPressed: service.isLoading ? null : service.logout,
                      child: const Text('Deconectare'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
