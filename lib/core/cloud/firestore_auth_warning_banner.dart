import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../auth/field_auth_service.dart';
import 'firestore_auth_warning_service.dart';

/// Banner persistent, non-blocant, afișat sub AppBar când sesiunea cloud nu e
/// validă (fallback auth local sau permission-denied Firestore confirmat).
///
/// Se conectează la [FirestoreAuthWarningService] (mecanism CENTRALIZAT) și
/// face bridge între notificările [FieldAuthService] (`authSourceLabel`) și
/// serviciu. Când permission-denied e confirmat, oferă butonul „Reconectează"
/// care deschide dialogul de re-login (Task 2).
class FirestoreAuthWarningBanner extends StatefulWidget {
  const FirestoreAuthWarningBanner({
    super.key,
    required this.authService,
  });

  final FieldAuthService authService;

  @override
  State<FirestoreAuthWarningBanner> createState() =>
      _FirestoreAuthWarningBannerState();
}

class _FirestoreAuthWarningBannerState
    extends State<FirestoreAuthWarningBanner> {
  @override
  void initState() {
    super.initState();
    widget.authService.addListener(_syncFromAuth);
    // Sincronizare inițială după primul frame (label-ul auth poate fi deja
    // 'local' din restaurarea sesiunii).
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFromAuth());
  }

  @override
  void dispose() {
    widget.authService.removeListener(_syncFromAuth);
    super.dispose();
  }

  /// Bridge: traduce starea `authSourceLabel` în starea serviciului central.
  void _syncFromAuth() {
    final svc = FirestoreAuthWarningService.instance;
    final label = widget.authService.authSourceLabel;
    if (widget.authService.isAuthenticated && label == 'local') {
      svc.reportLocalAuthFallback();
    } else if (label == 'cloud') {
      svc.clear();
    }
  }

  Future<void> _openReloginDialog() async {
    await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _ReloginDialog(authService: widget.authService),
    );
  }

  @override
  Widget build(BuildContext context) {
    final svc = FirestoreAuthWarningService.instance;
    return ListenableBuilder(
      listenable: Listenable.merge([
        svc.activeNotifier,
        svc.permissionDeniedNotifier,
      ]),
      builder: (context, _) {
        if (!svc.activeNotifier.value) {
          return const SizedBox.shrink();
        }
        final permissionDenied = svc.permissionDeniedNotifier.value;
        return Material(
          color: const Color(0xFFB71C1C), // roșu închis — avertisment
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Row(
              children: [
                const Icon(Icons.cloud_off_outlined,
                    color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Rulezi neautentificat la cloud — datele pot fi învechite '
                    'și modificările NU se vor sincroniza.',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: 12.5,
                    ),
                  ),
                ),
                if (permissionDenied) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: const Color(0xFFB71C1C),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _openReloginDialog,
                    icon: const Icon(Icons.login, size: 16),
                    label: const Text('Reconectează'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Dialog de re-autentificare cloud. Apelează DIRECT
/// `FirebaseAuth.signInWithEmailAndPassword` (NU calea locală de fallback) și
/// verifică explicit `currentUser != null` înainte de a raporta succes.
class _ReloginDialog extends StatefulWidget {
  const _ReloginDialog({required this.authService});

  final FieldAuthService authService;

  @override
  State<_ReloginDialog> createState() => _ReloginDialogState();
}

class _ReloginDialogState extends State<_ReloginDialog> {
  late final TextEditingController _emailController;
  final TextEditingController _passwordController = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(
      text: widget.authService.userEmail ?? '',
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Introdu email și parolă.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Verificare explicită: NU presupune succes doar pentru că nu a aruncat.
      if (FirebaseAuth.instance.currentUser == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Autentificare eșuată — sesiunea nu a fost creată.';
        });
        return;
      }
      // Reîmprospătează sesiunea (actualizează authSourceLabel → 'cloud').
      await widget.authService.restoreSession();
      // Verificare finală după refresh.
      if (FirebaseAuth.instance.currentUser == null) {
        if (!mounted) return;
        setState(() {
          _busy = false;
          _error = 'Sesiunea nu a putut fi confirmată. Încearcă din nou.';
        });
        return;
      }
      FirestoreAuthWarningService.instance.clear();
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _mapAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Eroare la reconectare: $e';
      });
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Parolă greșită. Încearcă din nou.';
      case 'user-not-found':
        return 'Utilizatorul nu există în cloud.';
      case 'user-disabled':
        return 'Cont dezactivat.';
      case 'network-request-failed':
        return 'Fără conexiune la internet. Verifică rețeaua.';
      case 'too-many-requests':
        return 'Prea multe încercări. Așteaptă puțin și reîncearcă.';
      default:
        return 'Reconectare eșuată (${e.code}).';
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      icon: const Icon(Icons.lock_reset_outlined, size: 34),
      title: const Text('Sesiunea cloud a expirat'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Reintrodu parola pentru a sincroniza datele cu cloud-ul.',
            style: TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _emailController,
            enabled: !_busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            enabled: !_busy,
            obscureText: _obscure,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(
              labelText: 'Parolă',
              prefixIcon: const Icon(Icons.lock_outline),
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFB71C1C), fontSize: 13),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Continuă offline'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Reconectează'),
        ),
      ],
    );
  }
}
