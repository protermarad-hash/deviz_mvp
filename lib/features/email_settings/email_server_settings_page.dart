import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import 'email_server_models.dart';
import 'email_server_service.dart';

class EmailServerSettingsPage extends StatefulWidget {
  const EmailServerSettingsPage({super.key});

  @override
  State<EmailServerSettingsPage> createState() =>
      _EmailServerSettingsPageState();
}

class _EmailServerSettingsPageState extends State<EmailServerSettingsPage> {
  final EmailServerService _service = EmailServerService();
  final Uuid _uuid = const Uuid();
  final TextEditingController _hostController = TextEditingController();
  final TextEditingController _portController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _fromEmailController = TextEditingController();
  final TextEditingController _fromNameController = TextEditingController();
  final TextEditingController _replyToController = TextEditingController();
  final TextEditingController _testEmailController = TextEditingController();

  List<EmailServerConfigRecord> _configs = const <EmailServerConfigRecord>[];
  List<EmailDeliveryLogRecord> _logs = const <EmailDeliveryLogRecord>[];
  EmailServerProviderPreset _provider = EmailServerProviderPreset.outlook365;
  bool _secure = false;
  bool _enabled = true;
  bool _loading = true;
  bool _saving = false;
  bool _testingConnection = false;
  bool _sendingTest = false;
  String _editingId = '';
  String _status = '';
  String _statusDetails = '';
  bool _statusIsError = false;
  bool _lastTestSucceeded = false;

  @override
  void initState() {
    super.initState();
    _applyProviderDefaults(_provider, replaceAll: true);
    _load();
  }

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _fromEmailController.dispose();
    _fromNameController.dispose();
    _replyToController.dispose();
    _testEmailController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _clearStatus();
    });
    try {
      final results = await Future.wait<dynamic>([
        _service.listConfigs(),
        _service.listDeliveryLogs(),
      ]);
      if (!mounted) return;
      setState(() {
        _configs = results[0] as List<EmailServerConfigRecord>;
        _logs = results[1] as List<EmailDeliveryLogRecord>;
        _loading = false;
      });
      if (_editingId.isEmpty && _configs.isNotEmpty) {
        _applyConfig(_configs.first);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _setErrorStatus(
          'Nu am putut incarca setarile email.',
          details: error.toString(),
        );
      });
    }
  }

  void _applyProviderDefaults(
    EmailServerProviderPreset provider, {
    bool replaceAll = false,
  }) {
    _provider = provider;
    _secure = provider.defaultSecure;
    if (replaceAll || _hostController.text.trim().isEmpty) {
      _hostController.text = provider.defaultHost;
    }
    if (replaceAll || _portController.text.trim().isEmpty) {
      _portController.text = provider.defaultPort.toString();
    }
  }

  void _applyConfig(EmailServerConfigRecord item) {
    setState(() {
      _editingId = item.id;
      _provider = item.provider;
      _hostController.text = item.host;
      _portController.text = item.port.toString();
      _secure = item.secure;
      _usernameController.text = item.username;
      _passwordController.clear();
      _fromEmailController.text = item.fromEmail;
      _fromNameController.text = item.fromName;
      _replyToController.text = item.replyToEmail;
      _enabled = item.enabled;
      _clearStatus();
    });
  }

  void _resetForm() {
    setState(() {
      _editingId = '';
      _provider = EmailServerProviderPreset.outlook365;
      _hostController.clear();
      _portController.clear();
      _usernameController.clear();
      _passwordController.clear();
      _fromEmailController.clear();
      _fromNameController.clear();
      _replyToController.clear();
      _testEmailController.clear();
      _enabled = true;
      _clearStatus();
    });
    _applyProviderDefaults(_provider, replaceAll: true);
  }

  void _setErrorStatus(String message, {String details = ''}) {
    _status = message;
    _statusDetails = details.trim();
    _statusIsError = true;
  }

  void _setInfoStatus(String message, {String details = ''}) {
    _status = message;
    _statusDetails = details.trim();
    _statusIsError = false;
  }

  void _clearStatus() {
    _status = '';
    _statusDetails = '';
    _statusIsError = false;
  }

  bool get _hasActiveConfig =>
      _configs.any((item) => item.isActive && item.enabled);

  EmailServerConfigRecord? get _editingConfig {
    if (_editingId.trim().isEmpty) return null;
    for (final item in _configs) {
      if (item.id == _editingId) return item;
    }
    return null;
  }

  int get _resolvedPort => int.tryParse(_portController.text.trim()) ?? 0;

  String? _validateSaveForm() {
    if (_hostController.text.trim().isEmpty) {
      return 'Host SMTP este obligatoriu.';
    }
    if (_resolvedPort <= 0 || _resolvedPort > 65535) {
      return 'Port SMTP invalid.';
    }
    if (_usernameController.text.trim().isEmpty) {
      return 'Username SMTP este obligatoriu.';
    }
    final hasIncomingPassword = _passwordController.text.trim().isNotEmpty;
    final hasStoredPassword = _editingConfig?.hasStoredPassword == true;
    if (!hasIncomingPassword && !hasStoredPassword) {
      return 'Lipseste parola SMTP.';
    }
    if (_fromEmailController.text.trim().isEmpty) {
      return 'From email este obligatoriu.';
    }
    if (_fromNameController.text.trim().isEmpty) {
      return 'From name este obligatoriu.';
    }
    if (_replyToController.text.trim().isEmpty) {
      return 'Reply-to email este obligatoriu.';
    }
    return null;
  }

  void _showFeedback(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _save() async {
    final validationError = _validateSaveForm();
    if (validationError != null) {
      setState(() {
        _setErrorStatus(validationError);
      });
      _showFeedback(validationError);
      return;
    }

    debugPrint('[SMTP][save] Click pe Salveaza');
    debugPrint('[SMTP][save] Payload preview: '
        'configId=${_editingId.isEmpty ? 'new' : _editingId}, '
        'provider=${_provider.value}, host=${_hostController.text.trim()}, '
        'port=$_resolvedPort, secure=$_secure, '
        'username=${_usernameController.text.trim()}, '
        'hasPassword=${_passwordController.text.trim().isNotEmpty || (_editingConfig?.hasStoredPassword == true)}, '
        'fromEmail=${_fromEmailController.text.trim()}, '
        'fromName=${_fromNameController.text.trim()}, '
        'replyTo=${_replyToController.text.trim()}, enabled=$_enabled');

    setState(() => _saving = true);
    try {
      final result = await _service.saveConfig(
        configId:
            _editingId.isEmpty ? 'email-config-${_uuid.v4()}' : _editingId,
        provider: _provider,
        host: _hostController.text,
        port: _resolvedPort,
        secure: _secure,
        username: _usernameController.text,
        password: _passwordController.text,
        fromEmail: _fromEmailController.text,
        fromName: _fromNameController.text,
        replyToEmail: _replyToController.text,
        enabled: _enabled,
      );
      debugPrint('[SMTP][save] Response: $result');
      final wasAutoActivated = result['autoActivated'] == true;
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            wasAutoActivated
                ? 'Configuratia SMTP a fost salvata si activata automat (prima configuratie).'
                : 'Configuratia SMTP a fost salvata.',
          ),
        ),
      );
      if (_lastTestSucceeded && !_hasActiveConfig) {
        setState(() {
          _setErrorStatus(
            'Testul a reusit, dar trebuie sa salvezi si sa activezi configuratia pentru ca Trimite direct sa o foloseasca.',
          );
        });
      } else {
        setState(() {
          _lastTestSucceeded = false;
          _clearStatus();
        });
      }
    } catch (error) {
      debugPrint('[SMTP][save] Error: $error');
      if (!mounted) return;
      String feedback = 'Salvarea a esuat.';
      setState(() {
        if (error is EmailServerActionException) {
          feedback = 'Salvarea a esuat: ${error.message}';
          _setErrorStatus(
            'Salvarea a esuat: ${error.message}',
            details: error.details,
          );
        } else {
          feedback = 'Salvarea a esuat: $error';
          _setErrorStatus('Salvarea a esuat.', details: error.toString());
        }
      });
      _showFeedback(feedback);
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _setActive(String configId) async {
    try {
      await _service.setActiveConfig(configId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Configuratia SMTP activa a fost actualizata.')),
      );
    } catch (error) {
      if (!mounted) return;
      String feedback = 'Nu am putut activa configuratia.';
      setState(() {
        if (error is EmailServerActionException) {
          feedback = 'Nu am putut activa configuratia: ${error.message}';
          _setErrorStatus(
            'Nu am putut activa configuratia: ${error.message}',
            details: error.details,
          );
        } else {
          feedback = 'Nu am putut activa configuratia: $error';
          _setErrorStatus(
            'Nu am putut activa configuratia.',
            details: error.toString(),
          );
        }
      });
      _showFeedback(feedback);
    }
  }

  Future<void> _testConnection() async {
    final validationError = _validateSaveForm();
    if (validationError != null) {
      setState(() {
        _setErrorStatus(validationError);
      });
      _showFeedback(validationError);
      return;
    }

    setState(() => _testingConnection = true);
    try {
      final result = await _service.testConnection(
        configId: _editingId,
        provider: _provider,
        host: _hostController.text,
        port: _resolvedPort,
        secure: _secure,
        username: _usernameController.text,
        password: _passwordController.text,
        fromEmail: _fromEmailController.text,
        fromName: _fromNameController.text,
        replyToEmail: _replyToController.text,
      );
      if (!mounted) return;
      setState(() {
        _lastTestSucceeded = true;
        if (_editingId.isEmpty || !_hasActiveConfig) {
          _setInfoStatus(
            'Testul a reusit, dar trebuie sa salvezi si sa activezi configuratia pentru ca Trimite direct sa o foloseasca.',
          );
        } else {
          _clearStatus();
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text((result['message'] ?? 'Conexiunea SMTP este validă.')
                .toString())),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      String feedback = 'Testul conexiunii a esuat.';
      setState(() {
        _lastTestSucceeded = false;
        if (error is EmailServerActionException) {
          feedback = 'Testul conexiunii a esuat: ${error.message}';
          _setErrorStatus(
            'Testul conexiunii a esuat: ${error.message}',
            details: error.details,
          );
        } else {
          feedback = 'Testul conexiunii a esuat: $error';
          _setErrorStatus(
            'Testul conexiunii a esuat.',
            details: error.toString(),
          );
        }
      });
      _showFeedback(feedback);
    } finally {
      if (mounted) {
        setState(() => _testingConnection = false);
      }
    }
  }

  Future<void> _sendTestEmail() async {
    final validationError = _validateSaveForm();
    if (validationError != null) {
      setState(() {
        _setErrorStatus(validationError);
      });
      _showFeedback(validationError);
      return;
    }

    final toEmail = _testEmailController.text.trim();
    if (toEmail.isEmpty) {
      setState(() {
        _setErrorStatus('Completeaza adresa pentru emailul de test.');
      });
      _showFeedback('Completeaza adresa pentru emailul de test.');
      return;
    }
    setState(() => _sendingTest = true);
    try {
      final result = await _service.sendTestEmail(
        configId: _editingId,
        toEmail: toEmail,
        provider: _provider,
        host: _hostController.text,
        port: _resolvedPort,
        secure: _secure,
        username: _usernameController.text,
        password: _passwordController.text,
        fromEmail: _fromEmailController.text,
        fromName: _fromNameController.text,
        replyToEmail: _replyToController.text,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                (result['message'] ?? 'Emailul de test a fost pus in coada.')
                    .toString())),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      String feedback = 'Trimiterea emailului de test a esuat.';
      setState(() {
        if (error is EmailServerActionException) {
          feedback = 'Trimiterea emailului de test a esuat: ${error.message}';
          _setErrorStatus(
            'Trimiterea emailului de test a esuat: ${error.message}',
            details: error.details,
          );
        } else {
          feedback = 'Trimiterea emailului de test a esuat: $error';
          _setErrorStatus(
            'Trimiterea emailului de test a esuat.',
            details: error.toString(),
          );
        }
      });
      _showFeedback(feedback);
    } finally {
      if (mounted) {
        setState(() => _sendingTest = false);
      }
    }
  }

  Widget _buildConfigList() {
    if (_configs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Nu exista inca servere email configurate.'),
      );
    }
    return Column(
      children: _configs
          .map(
            (item) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(item.fromName.trim().isEmpty
                    ? item.fromEmail
                    : item.fromName),
                subtitle: Text(
                  '${item.provider.label} | ${item.host}:${item.port} | ${item.fromEmail}${item.isActive ? ' | Activ' : ''}${item.lastTestStatus.trim().isNotEmpty ? ' | Test: ${item.lastTestStatus}' : ''}',
                ),
                trailing: Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton(
                      onPressed: () => _applyConfig(item),
                      child: const Text('Editeaza'),
                    ),
                    FilledButton.tonal(
                      onPressed:
                          item.isActive ? null : () => _setActive(item.id),
                      child: const Text('Seteaza activ'),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(growable: false),
    );
  }

  Widget _buildLogList() {
    if (_logs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: Text('Nu exista inca loguri de livrare email.'),
      );
    }
    return Column(
      children: _logs.take(20).map(
        (item) {
          final sentAtText = item.sentAt?.toLocal().toString().split('.').first;
          final createdAtText =
              item.createdAt.toLocal().toString().split('.').first;
          final visibleDate = sentAtText ?? createdAtText;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${item.subject} -> ${item.to}'),
            subtitle: Text(
              '${item.sourceModule}/${item.sourceEntityId} | ${item.status.value} | Data: $visibleDate | Incercari: ${item.attemptCount}${item.errorMessage.trim().isNotEmpty ? ' | Eroare: ${item.errorMessage}' : ''}',
            ),
          );
        },
      ).toList(growable: false),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Setari email / server SMTP')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trimite direct folosește coada server-side și configuratia SMTP activa. Deschide Outlook rămâne doar fallback de precompletare.',
                  ),
                  if (!_hasActiveConfig) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Nu exista server email activ. Trimiterea directa nu va functiona pana nu salvezi si activezi o configuratie SMTP.',
                      style:
                          TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                  if (_status.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _status,
                      style: TextStyle(
                        color: _statusIsError
                            ? Theme.of(context).colorScheme.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    if (_statusDetails.trim().isNotEmpty)
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        title: const Text('Detalii tehnice'),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: SelectableText(
                              _statusDetails,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _editingId.isEmpty
                              ? 'Server nou'
                              : 'Editeaza server SMTP',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      TextButton(
                        onPressed: _resetForm,
                        child: const Text('Nou'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<EmailServerProviderPreset>(
                    initialValue: _provider,
                    decoration:
                        const InputDecoration(labelText: 'Provider preset'),
                    items: EmailServerProviderPreset.values
                        .map(
                          (item) => DropdownMenuItem<EmailServerProviderPreset>(
                            value: item,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() =>
                          _applyProviderDefaults(value, replaceAll: true));
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _hostController,
                    decoration: const InputDecoration(labelText: 'Host'),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(labelText: 'Port'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _secure,
                          onChanged: (value) => setState(() => _secure = value),
                          title: const Text('Secure / SSL'),
                        ),
                      ),
                    ],
                  ),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _usernameController,
                    decoration: const InputDecoration(labelText: 'Username'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Parola',
                      helperText:
                          'Lasă gol la editare ca să păstrezi parola existentă.',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _fromEmailController,
                    decoration: const InputDecoration(labelText: 'From email'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    textCapitalization: TextCapitalization.sentences,
                    controller: _fromNameController,
                    decoration: const InputDecoration(labelText: 'From name'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _replyToController,
                    decoration:
                        const InputDecoration(labelText: 'Reply-to email'),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: _enabled,
                    onChanged: (value) => setState(() => _enabled = value),
                    title: const Text('Configuratie activabila'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _testEmailController,
                    decoration:
                        const InputDecoration(labelText: 'Email pentru test'),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: _testingConnection ? null : _testConnection,
                        icon: const Icon(Icons.network_check_outlined),
                        label: const Text('Testeaza conexiunea'),
                      ),
                      OutlinedButton.icon(
                        onPressed: _sendingTest ? null : _sendTestEmail,
                        icon: const Icon(Icons.mark_email_read_outlined),
                        label: const Text('Trimite email test'),
                      ),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: const Icon(Icons.save_outlined),
                        label: const Text('Salveaza'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Configuratii salvate',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildConfigList(),
                ],
              ),
            ),
          ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Log livrare email',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 12),
                  _buildLogList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
