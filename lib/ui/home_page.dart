import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/app_models.dart';
import '../core/local_store.dart';
import '../core/pdf_service.dart';
import '../features/registratura/registry_store.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, required this.repository});

  final AppRepository repository;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;
  int _refreshTick = 0;

  void _refresh() {
    setState(() {
      _refreshTick++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DashboardPage(repository: widget.repository, refreshTick: _refreshTick),
      ClientsPage(repository: widget.repository, onChanged: _refresh),
      MaterialsPage(repository: widget.repository, onChanged: _refresh),
      EmployeesPage(repository: widget.repository, onChanged: _refresh),
      VehiclesPage(repository: widget.repository, onChanged: _refresh),
      OverheadPage(repository: widget.repository, onChanged: _refresh),
      OffersPage(repository: widget.repository, onChanged: _refresh),
      CompanySettingsPage(repository: widget.repository, onChanged: _refresh),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('ProVentaris')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final compactRail = width < 1280;

          return Row(
            children: [
              NavigationRail(
                selectedIndex: _index,
                onDestinationSelected: (value) =>
                    setState(() => _index = value),
                labelType: compactRail
                    ? NavigationRailLabelType.selected
                    : NavigationRailLabelType.all,
                minWidth: compactRail ? 64 : 72,
                groupAlignment: -0.95,
                destinations: const [
                  NavigationRailDestination(
                    icon: Icon(Icons.dashboard_outlined),
                    selectedIcon: Icon(Icons.dashboard),
                    label: Text('Dashboard'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.business_outlined),
                    selectedIcon: Icon(Icons.business),
                    label: Text('Clienți'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.inventory_2_outlined),
                    selectedIcon: Icon(Icons.inventory_2),
                    label: Text('Materiale'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.groups_outlined),
                    selectedIcon: Icon(Icons.groups),
                    label: Text('Angajați'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.directions_car_outlined),
                    selectedIcon: Icon(Icons.directions_car),
                    label: Text('Autoturisme'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.account_balance_wallet_outlined),
                    selectedIcon: Icon(Icons.account_balance_wallet),
                    label: Text('Regie'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.request_quote_outlined),
                    selectedIcon: Icon(Icons.request_quote),
                    label: Text('Oferte'),
                  ),
                  NavigationRailDestination(
                    icon: Icon(Icons.settings_outlined),
                    selectedIcon: Icon(Icons.settings),
                    label: Text('Setări firmă'),
                  ),
                ],
              ),
              SizedBox(width: compactRail ? 8 : 12),
              Expanded(child: pages[_index]),
            ],
          );
        },
      ),
    );
  }
}

class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.repository,
    required this.refreshTick,
  });

  final AppRepository repository;
  final int refreshTick;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: repository.loadDashboardData(),
      builder: (context, snapshot) {
        final data = snapshot.data;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dashboard',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatCard(title: 'Oferte', value: '${data?['offers'] ?? 0}'),
                  _StatCard(
                    title: 'Clienți',
                    value: '${data?['clients'] ?? 0}',
                  ),
                  _StatCard(
                    title: 'Materiale',
                    value: '${data?['materials'] ?? 0}',
                  ),
                  _StatCard(
                    title: 'Angajați activi',
                    value: '${data?['employees'] ?? 0}',
                  ),
                  _StatCard(
                    title: 'Autoturisme active',
                    value: '${data?['vehicles'] ?? 0}',
                  ),
                  _StatCard(
                    title: 'Firma',
                    value: valueText(data?['company_name'], fallback: '-'),
                  ),
                  _StatCard(
                    title: 'TVA implicit',
                    value: '${parseDouble(data?['vat']).toStringAsFixed(0)}%',
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class ClientsPage extends StatefulWidget {
  const ClientsPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<ClientsPage> createState() => _ClientsPageState();
}

class _ClientsPageState extends State<ClientsPage> {
  Future<void> _deleteClient(Map<String, dynamic> client) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge client'),
        content: Text('Ștergi clientul "${valueText(client['name'])}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteClient(valueText(client['id']));
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editClient([Map<String, dynamic>? client]) async {
    final name = TextEditingController(text: valueText(client?['name']));
    final contact =
        TextEditingController(text: valueText(client?['contact_person']));
    final phone = TextEditingController(text: valueText(client?['phone']));
    final email = TextEditingController(text: valueText(client?['email']));

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(client == null ? 'Client nou' : 'Editează client'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(name, 'Nume client'),
              _textField(contact, 'Persoană contact'),
              _textField(phone, 'Telefon'),
              _textField(email, 'Email'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.saveClient({
                'id': client?['id'],
                'name': name.text.trim(),
                'contact_person': contact.text.trim(),
                'phone': phone.text.trim(),
                'email': email.text.trim(),
              });
              if (!mounted || !context.mounted) {
                return;
              }
              Navigator.pop(context);
              setState(() {});
              widget.onChanged();
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Clienți',
      action: FilledButton.icon(
        onPressed: _editClient,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.repository.listClients(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          debugPrint(
            '[ClientsPage] loaded: ${items.length} using query table=clients eq user_id=$localUserId order=name',
          );
          for (final item in items) {
            debugPrint(
              '[ClientsPage] item: id=${item['id']}, name=${item['name']}, phone=${item['phone']}, contact=${item['contact_person']}',
            );
          }
          return Card(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(valueText(item['name'])),
                  subtitle: Text(
                    '${valueText(item['contact_person'])} • ${valueText(item['phone'])}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 160,
                        child: Text(
                          valueText(item['email']),
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        onPressed: () => _editClient(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteClient(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => _editClient(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class MaterialsPage extends StatefulWidget {
  const MaterialsPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<MaterialsPage> createState() => _MaterialsPageState();
}

class _MaterialsPageState extends State<MaterialsPage> {
  Future<void> _deleteMaterial(Map<String, dynamic> material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge material'),
        content: Text('Ștergi materialul "${valueText(material['name'])}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteMaterial(valueText(material['id']));
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editMaterial([Map<String, dynamic>? material]) async {
    final name = TextEditingController(text: valueText(material?['name']));
    final unit = TextEditingController(
      text: valueText(material?['unit'], fallback: 'buc'),
    );
    final price = TextEditingController(
      text: parseDouble(material?['sell_price']).toStringAsFixed(2),
    );

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(material == null ? 'Material nou' : 'Editează material'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(name, 'Denumire'),
              _textField(unit, 'UM'),
              _numberField(price, 'Preț vânzare'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () async {
              await widget.repository.saveMaterial({
                'id': material?['id'],
                'name': name.text.trim(),
                'unit': unit.text.trim(),
                'sell_price': parseDouble(price.text),
              });
              if (!mounted || !context.mounted) {
                return;
              }
              Navigator.pop(context);
              setState(() {});
              widget.onChanged();
            },
            child: const Text('Salvează'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Materiale',
      action: FilledButton.icon(
        onPressed: _editMaterial,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.repository.listMaterials(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          debugPrint(
            '[MaterialsPage] loaded: ${items.length} using query table=materials eq user_id=$localUserId order=name',
          );
          return Card(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(valueText(item['name'])),
                  subtitle: Text(valueText(item['unit'])),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${parseDouble(item['sell_price']).toStringAsFixed(2)} RON',
                      ),
                      IconButton(
                        onPressed: () => _editMaterial(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteMaterial(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => _editMaterial(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final Uuid _uuid = const Uuid();

  Future<void> _deleteEmployee(EmployeeRecord employee) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge angajat'),
        content: Text('Ștergi angajatul "${employee.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteEmployee(employee.id);
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editEmployee([EmployeeRecord? employee]) async {
    final name = TextEditingController(text: employee?.name ?? '');
    final role = TextEditingController(text: employee?.role ?? '');
    final hourlyRate = TextEditingController(
      text: (employee?.hourlyRate ?? 0).toStringAsFixed(2),
    );
    final internalCost = TextEditingController(
      text: (employee?.internalHourlyCost ?? 0).toStringAsFixed(2),
    );
    final monthlySalary = TextEditingController(
      text: (employee?.monthlySalaryOptional ?? 0).toStringAsFixed(2),
    );
    final perDiem = TextEditingController(
      text: (employee?.perDiemPerDay ?? 0).toStringAsFixed(2),
    );
    final lodging = TextEditingController(
      text: (employee?.lodgingPerDay ?? 0).toStringAsFixed(2),
    );
    final notes = TextEditingController(text: employee?.notes ?? '');
    var active = employee?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(employee == null ? 'Angajat nou' : 'Editează angajat'),
          content: SizedBox(
            width: 520,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _textField(name, 'Nume'),
                _textField(role, 'Rol'),
                _numberField(hourlyRate, 'Tarif orar'),
                _numberField(internalCost, 'Cost intern / ora'),
                _numberField(monthlySalary, 'Salariu lunar optional'),
                _numberField(perDiem, 'Diurna / zi'),
                _numberField(lodging, 'Cazare / zi'),
                _textField(notes, 'Observații'),
                const SizedBox(height: 8),
                SwitchListTile(
                  value: active,
                  onChanged: (value) => setDialogState(() => active = value),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Activ'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.saveEmployee(
                  EmployeeRecord(
                    id: employee?.id ?? _uuid.v4(),
                    name: name.text.trim(),
                    role: role.text.trim(),
                    hourlyRate: parseDouble(hourlyRate.text),
                    internalHourlyCost: parseDouble(internalCost.text),
                    monthlySalaryOptional: parseDouble(monthlySalary.text),
                    perDiemPerDay: parseDouble(perDiem.text),
                    lodgingPerDay: parseDouble(lodging.text),
                    active: active,
                    notes: notes.text.trim(),
                  ),
                );
                if (!mounted || !context.mounted) {
                  return;
                }
                Navigator.pop(context);
                setState(() {});
                widget.onChanged();
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Angajați',
      action: FilledButton.icon(
        onPressed: _editEmployee,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă'),
      ),
      child: FutureBuilder<List<EmployeeRecord>>(
        future: widget.repository.listEmployees(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return Card(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(item.name),
                  subtitle: Text(
                    '${item.role} • ${item.hourlyRate.toStringAsFixed(2)} RON/h${item.notes.trim().isNotEmpty ? ' • ${item.notes.trim()}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.active ? 'Activ' : 'Inactiv'),
                      IconButton(
                        onPressed: () => _editEmployee(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteEmployee(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => _editEmployee(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<VehiclesPage> createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  final Uuid _uuid = const Uuid();

  Future<void> _deleteVehicle(VehicleRecord vehicle) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Șterge autoturism'),
        content: Text('Ștergi autoturismul "${vehicle.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Renunță'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Șterge'),
          ),
        ],
      ),
    );
    if (confirm != true) {
      return;
    }
    await widget.repository.deleteVehicle(vehicle.id);
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged();
  }

  Future<void> _editVehicle([VehicleRecord? vehicle]) async {
    final plate = TextEditingController(text: vehicle?.plateNumber ?? '');
    final name = TextEditingController(text: vehicle?.name ?? '');
    final fuelType = TextEditingController(text: vehicle?.fuelType ?? '');
    final consumption = TextEditingController(
      text: (vehicle?.fuelConsumptionLPer100Km ?? 0).toStringAsFixed(2),
    );
    final fuelPrice = TextEditingController(
      text: (vehicle?.fuelPricePerLiter ?? 0).toStringAsFixed(2),
    );
    final costPerKm = TextEditingController(
      text: (vehicle?.costPerKmOptional ?? 0).toStringAsFixed(2),
    );
    final purchasePrice = TextEditingController(
      text: (vehicle?.purchasePrice ?? 0).toStringAsFixed(2),
    );
    final fixedDaily = TextEditingController(
      text: (vehicle?.fixedDailyCost ?? 0).toStringAsFixed(2),
    );
    final leasing = TextEditingController(
      text: (vehicle?.monthlyLeasingCost ?? 0).toStringAsFixed(2),
    );
    final insurance = TextEditingController(
      text: (vehicle?.insuranceCostOptional ?? 0).toStringAsFixed(2),
    );
    final maintenance = TextEditingController(
      text: (vehicle?.maintenanceCostOptional ?? 0).toStringAsFixed(2),
    );
    final depreciationMonths = TextEditingController(
      text: (vehicle?.depreciationMonths ?? 60).toString(),
    );
    final annualInsurance = TextEditingController(
      text: (vehicle?.annualInsuranceCost ?? 0).toStringAsFixed(2),
    );
    final annualTax = TextEditingController(
      text: (vehicle?.annualTaxCost ?? 0).toStringAsFixed(2),
    );
    final annualRovinieta = TextEditingController(
      text: (vehicle?.annualRovinietaCost ?? 0).toStringAsFixed(2),
    );
    final annualItp = TextEditingController(
      text: (vehicle?.annualItpCost ?? 0).toStringAsFixed(2),
    );
    final annualMaintenanceBudget = TextEditingController(
      text: (vehicle?.annualMaintenanceBudget ?? 0).toStringAsFixed(2),
    );
    final annualRepairBudget = TextEditingController(
      text: (vehicle?.annualRepairBudget ?? 0).toStringAsFixed(2),
    );
    final tireSetCost = TextEditingController(
      text: (vehicle?.tireSetCost ?? 0).toStringAsFixed(2),
    );
    final tireReplacementMonths = TextEditingController(
      text: (vehicle?.tireReplacementMonths ?? 48).toString(),
    );
    final productiveHoursPerMonth = TextEditingController(
      text: (vehicle?.productiveHoursPerMonth ?? 168).toStringAsFixed(2),
    );
    final expectedAnnualKm = TextEditingController(
      text: (vehicle?.expectedAnnualKm ?? 0).toStringAsFixed(2),
    );
    final otherPerKmCost = TextEditingController(
      text: (vehicle?.otherPerKmCost ?? 0).toStringAsFixed(2),
    );
    final notes = TextEditingController(text: vehicle?.notes ?? '');
    var acquisitionType = vehicle?.normalizedAcquisitionType ?? 'purchase';
    var active = vehicle?.active ?? true;

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title:
              Text(vehicle == null ? 'Autoturism nou' : 'Editează autoturism'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _textField(plate, 'Număr auto'),
                  _textField(name, 'Denumire'),
                  _textField(fuelType, 'Tip combustibil'),
                  DropdownButtonFormField<String>(
                    initialValue: acquisitionType,
                    decoration:
                        const InputDecoration(labelText: 'Tip achiziție'),
                    items: const [
                      DropdownMenuItem(
                        value: 'purchase',
                        child: Text('Purchase'),
                      ),
                      DropdownMenuItem(
                        value: 'leasing',
                        child: Text('Leasing'),
                      ),
                    ],
                    onChanged: (value) => setDialogState(
                      () => acquisitionType = value ?? 'purchase',
                    ),
                  ),
                  _numberField(consumption, 'Consum l / 100 km'),
                  _numberField(fuelPrice, 'Preț combustibil / l'),
                  _numberField(costPerKm, 'Cost / km optional'),
                  _numberField(purchasePrice, 'Cost achiziție'),
                  _numberField(fixedDaily, 'Cost fix zilnic'),
                  _numberField(leasing, 'Cost lunar leasing'),
                  _numberField(insurance, 'Asigurare optional'),
                  _numberField(maintenance, 'Mentenanta optional'),
                  _numberField(depreciationMonths, 'Amortizare (luni)'),
                  _numberField(annualInsurance, 'Asigurări / an'),
                  _numberField(annualTax, 'Impozit / an'),
                  _numberField(annualRovinieta, 'Rovinieta / an'),
                  _numberField(annualItp, 'ITP / an'),
                  _numberField(
                    annualMaintenanceBudget,
                    'Mentenanta buget / an',
                  ),
                  _numberField(annualRepairBudget, 'Reparații buget / an'),
                  _numberField(tireSetCost, 'Set anvelope'),
                  _numberField(
                    tireReplacementMonths,
                    'Înlocuire anvelope (luni)',
                  ),
                  _numberField(
                    productiveHoursPerMonth,
                    'Ore productive / lună',
                  ),
                  _numberField(expectedAnnualKm, 'Km estimați / an'),
                  _numberField(otherPerKmCost, 'Alte costuri / km'),
                  _textField(notes, 'Observații'),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: active,
                    onChanged: (value) => setDialogState(() => active = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Activ'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () async {
                await widget.repository.saveVehicle(
                  VehicleRecord(
                    id: vehicle?.id ?? _uuid.v4(),
                    plateNumber: plate.text.trim(),
                    name: name.text.trim(),
                    fuelType: fuelType.text.trim(),
                    fuelConsumptionLPer100Km: parseDouble(consumption.text),
                    fuelPricePerLiter: parseDouble(fuelPrice.text),
                    costPerKmOptional: parseDouble(costPerKm.text),
                    acquisitionType: acquisitionType,
                    purchasePrice: parseDouble(purchasePrice.text),
                    fixedDailyCost: parseDouble(fixedDaily.text),
                    monthlyLeasingCost: parseDouble(leasing.text),
                    insuranceCostOptional: parseDouble(insurance.text),
                    maintenanceCostOptional: parseDouble(maintenance.text),
                    depreciationMonths:
                        parseDouble(depreciationMonths.text).round(),
                    annualInsuranceCost: parseDouble(annualInsurance.text),
                    annualTaxCost: parseDouble(annualTax.text),
                    annualRovinietaCost: parseDouble(annualRovinieta.text),
                    annualItpCost: parseDouble(annualItp.text),
                    annualMaintenanceBudget:
                        parseDouble(annualMaintenanceBudget.text),
                    annualRepairBudget: parseDouble(annualRepairBudget.text),
                    tireSetCost: parseDouble(tireSetCost.text),
                    tireReplacementMonths:
                        parseDouble(tireReplacementMonths.text).round(),
                    productiveHoursPerMonth:
                        parseDouble(productiveHoursPerMonth.text),
                    expectedAnnualKm: parseDouble(expectedAnnualKm.text),
                    otherPerKmCost: parseDouble(otherPerKmCost.text),
                    active: active,
                    notes: notes.text.trim(),
                  ),
                );
                if (!mounted || !context.mounted) {
                  return;
                }
                Navigator.pop(context);
                setState(() {});
                widget.onChanged();
              },
              child: const Text('Salvează'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Autoturisme',
      action: FilledButton.icon(
        onPressed: _editVehicle,
        icon: const Icon(Icons.add),
        label: const Text('Adaugă'),
      ),
      child: FutureBuilder<List<VehicleRecord>>(
        future: widget.repository.listVehicles(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return Card(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text('${item.name} (${item.plateNumber})'),
                  subtitle: Text(
                    '${item.fuelType} • ${item.effectiveCostPerKm.toStringAsFixed(2)} RON/km${item.notes.trim().isNotEmpty ? ' • ${item.notes.trim()}' : ''}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(item.active ? 'Activ' : 'Inactiv'),
                      IconButton(
                        onPressed: () => _editVehicle(item),
                        icon: const Icon(Icons.edit_outlined),
                      ),
                      IconButton(
                        onPressed: () => _deleteVehicle(item),
                        icon: const Icon(Icons.delete_outline),
                      ),
                    ],
                  ),
                  onTap: () => _editVehicle(item),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class OverheadPage extends StatefulWidget {
  const OverheadPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<OverheadPage> createState() => _OverheadPageState();
}

class _OverheadPageState extends State<OverheadPage> {
  bool _loading = true;
  String _mode = overheadModePercent;
  late final TextEditingController _percent;
  late final TextEditingController _accounting;
  late final TextEditingController _psiSsm;
  late final TextEditingController _insurance;
  late final TextEditingController _phone;
  late final TextEditingController _admin;
  late final TextEditingController _consumables;
  late final TextEditingController _other;

  @override
  void initState() {
    super.initState();
    _percent = TextEditingController();
    _accounting = TextEditingController();
    _psiSsm = TextEditingController();
    _insurance = TextEditingController();
    _phone = TextEditingController();
    _admin = TextEditingController();
    _consumables = TextEditingController();
    _other = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.getOverheadSettings();
    _mode = _resolveDropdownValue(
          settings.defaultOverheadMode,
          _overheadModeDropdownOptions,
          fallback: overheadModePercent,
        ) ??
        overheadModePercent;
    _percent.text = settings.defaultOverheadPercent.toStringAsFixed(2);
    _accounting.text = settings.accountingMonthly.toStringAsFixed(2);
    _psiSsm.text = settings.psiSsmMonthly.toStringAsFixed(2);
    _insurance.text = settings.insuranceMonthly.toStringAsFixed(2);
    _phone.text = settings.phoneMonthly.toStringAsFixed(2);
    _admin.text = settings.adminMonthly.toStringAsFixed(2);
    _consumables.text = settings.consumablesMonthly.toStringAsFixed(2);
    _other.text = settings.otherMonthly.toStringAsFixed(2);
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PageShell(
      title: 'Regie',
      action: FilledButton.icon(
        onPressed: () async {
          await widget.repository.saveOverheadSettings(
            OverheadSettings(
              defaultOverheadMode: _mode,
              defaultOverheadPercent: parseDouble(_percent.text),
              accountingMonthly: parseDouble(_accounting.text),
              psiSsmMonthly: parseDouble(_psiSsm.text),
              insuranceMonthly: parseDouble(_insurance.text),
              phoneMonthly: parseDouble(_phone.text),
              adminMonthly: parseDouble(_admin.text),
              consumablesMonthly: parseDouble(_consumables.text),
              otherMonthly: parseDouble(_other.text),
            ),
          );
          if (!context.mounted) {
            return;
          }
          widget.onChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setarile de regie au fost salvate.')),
          );
        },
        icon: const Icon(Icons.save),
        label: const Text('Salveaza'),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              DropdownButtonFormField<String>(
                initialValue: _mode,
                items: const [
                  DropdownMenuItem(
                    value: overheadModePercent,
                    child: Text('Procent'),
                  ),
                  DropdownMenuItem(
                    value: overheadModeCalculated,
                    child: Text('Calculata'),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => _mode = value ?? overheadModePercent),
                decoration:
                    const InputDecoration(labelText: 'Mod implicit regie'),
              ),
              const SizedBox(height: 16),
              _numberField(_percent, 'Procent implicit regie'),
              const SizedBox(height: 16),
              _numberField(_accounting, 'Contabilitate lunar'),
              const SizedBox(height: 16),
              _numberField(_psiSsm, 'PSI / SSM lunar'),
              const SizedBox(height: 16),
              _numberField(_insurance, 'Asigurari lunar'),
              const SizedBox(height: 16),
              _numberField(_phone, 'Telefon lunar'),
              const SizedBox(height: 16),
              _numberField(_admin, 'Administrativ lunar'),
              const SizedBox(height: 16),
              _numberField(_consumables, 'Consumabile lunar'),
              const SizedBox(height: 16),
              _numberField(_other, 'Altele lunar'),
            ],
          ),
        ),
      ),
    );
  }
}

class CompanySettingsPage extends StatefulWidget {
  const CompanySettingsPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<CompanySettingsPage> createState() => _CompanySettingsPageState();
}

class _CompanySettingsPageState extends State<CompanySettingsPage> {
  late TextEditingController _eurRate;
  bool _loading = true;
  String? _logoBase64;
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _cui;
  late final TextEditingController _tradeRegister;
  late final TextEditingController _bank;
  late final TextEditingController _iban;
  late final TextEditingController _contactName;
  late final TextEditingController _currency;
  late final TextEditingController _vat;
  late final TextEditingController _profit;
  late final TextEditingController _overhead;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController();
    _address = TextEditingController();
    _phone = TextEditingController();
    _email = TextEditingController();
    _cui = TextEditingController();
    _tradeRegister = TextEditingController();
    _bank = TextEditingController();
    _iban = TextEditingController();
    _contactName = TextEditingController();
    _currency = TextEditingController();
    _vat = TextEditingController();
    _eurRate = TextEditingController();
    _profit = TextEditingController();
    _overhead = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final settings = await widget.repository.getCompanySettings();
    _name.text = settings.companyName;
    _address.text = settings.companyAddress;
    _phone.text = settings.companyPhone;
    _email.text = settings.companyEmail;
    _cui.text = settings.companyCui;
    _tradeRegister.text = settings.companyTradeRegister;
    _bank.text = settings.companyBank;
    _iban.text = settings.companyIban;
    _contactName.text = settings.companyContactName;
    _currency.text = _resolveDropdownValue(
          settings.defaultCurrency,
          _currencyDropdownOptions,
          fallback: 'RON',
        ) ??
        'RON';
    _vat.text = settings.defaultVatPercent.toStringAsFixed(2);
    _eurRate.text = settings.defaultEurRate.toStringAsFixed(2);
    _profit.text = settings.defaultProfitPercent.toStringAsFixed(2);
    _overhead.text = settings.defaultOverheadPercent.toStringAsFixed(2);
    _logoBase64 = settings.companyLogoBase64;
    if (!mounted) {
      return;
    }
    setState(() => _loading = false);
  }

  Future<void> _pickLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return;
    }
    setState(() {
      _logoBase64 = base64Encode(bytes);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    return _PageShell(
      title: 'Setari firma',
      action: FilledButton.icon(
        onPressed: () async {
          await widget.repository.saveCompanySettings(
            CompanySettings(
              companyName: _name.text.trim(),
              defaultEurRate: parseDouble(_eurRate.text, fallback: 5),
              companyAddress: _address.text.trim(),
              companyPhone: _phone.text.trim(),
              companyEmail: _email.text.trim(),
              companyCui: _cui.text.trim(),
              companyTradeRegister: _tradeRegister.text.trim(),
              companyBank: _bank.text.trim(),
              companyIban: _iban.text.trim(),
              companyContactName: _contactName.text.trim(),
              companyLogoBase64: _logoBase64,
              defaultCurrency: _resolveDropdownValue(
                    _currency.text,
                    _currencyDropdownOptions,
                    fallback: 'RON',
                  ) ??
                  'RON',
              defaultVatPercent: parseDouble(_vat.text),
              defaultProfitPercent: parseDouble(_profit.text),
              defaultOverheadPercent: parseDouble(_overhead.text),
            ),
          );
          if (!context.mounted) {
            return;
          }
          widget.onChanged();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Setarile firmei au fost salvate.')),
          );
        },
        icon: const Icon(Icons.save),
        label: const Text('Salveaza'),
      ),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ListView(
            children: [
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(width: 320, child: _textField(_name, 'Nume firma')),
                  SizedBox(width: 220, child: _textField(_phone, 'Telefon')),
                  SizedBox(width: 320, child: _textField(_email, 'Email')),
                  SizedBox(width: 220, child: _textField(_cui, 'CUI')),
                  SizedBox(
                    width: 260,
                    child:
                        _textField(_tradeRegister, 'Nr. registrul comertului'),
                  ),
                  SizedBox(width: 260, child: _textField(_bank, 'Banca')),
                  SizedBox(width: 320, child: _textField(_iban, 'IBAN')),
                  SizedBox(
                    width: 260,
                    child: _textField(_contactName, 'Persoana contact'),
                  ),
                  SizedBox(
                    width: 580,
                    child: TextField(
                      controller: _address,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Adresa'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 140,
                    child: _textField(_currency, 'Moneda implicita'),
                  ),
                  SizedBox(
                      width: 160, child: _numberField(_vat, 'TVA implicit')),
                  SizedBox(
                    width: 160,
                    child: _numberField(_profit, 'Profit implicit'),
                  ),
                  SizedBox(
                    width: 160,
                    child: _numberField(_overhead, 'Regie implicita'),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  OutlinedButton.icon(
                    onPressed: _pickLogo,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                        _logoBase64 == null ? 'Alege logo' : 'Schimba logo'),
                  ),
                  if (_logoBase64 != null)
                    TextButton(
                      onPressed: () => setState(() => _logoBase64 = null),
                      child: const Text('Șterge logo'),
                    ),
                  Text(_logoBase64 == null
                      ? 'Fara logo salvat'
                      : 'Logo salvat local'),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OffersPage extends StatefulWidget {
  const OffersPage({
    super.key,
    required this.repository,
    required this.onChanged,
  });

  final AppRepository repository;
  final VoidCallback onChanged;

  @override
  State<OffersPage> createState() => _OffersPageState();
}

class _OffersPageState extends State<OffersPage> {
  Future<void> _openEditor([String? offerId]) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => OfferEditorPage(
          repository: widget.repository,
          offerId: offerId,
        ),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() {});
    widget.onChanged();
  }

  @override
  Widget build(BuildContext context) {
    return _PageShell(
      title: 'Oferte',
      action: FilledButton.icon(
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: const Text('Oferta noua'),
      ),
      child: FutureBuilder<List<Map<String, dynamic>>>(
        future: widget.repository.listOffers(),
        builder: (context, snapshot) {
          final items = snapshot.data ?? [];
          return Card(
            child: ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final item = items[index];
                return ListTile(
                  title: Text(valueText(item['number'])),
                  subtitle: Text(
                    'Data: ${valueText(item['offer_date'])} • ${valueText(item['titlu_oferta'])}${valueText(item['titlu_oferta']).trim().isNotEmpty && valueText(item['locatie_lucrare']).trim().isNotEmpty ? ' • ' : ''}${valueText(item['locatie_lucrare'])}${(valueText(item['titlu_oferta']).trim().isNotEmpty || valueText(item['locatie_lucrare']).trim().isNotEmpty) ? ' • ' : ''}Total: ${formatMoney(parseDouble(item['grand_total']), currency: valueText(item['currency'], fallback: 'RON'), eurRate: parseDouble(item['eur_rate'], fallback: 5))}',
                  ),
                  onTap: () => _openEditor(valueText(item['id'])),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class OfferEditorPage extends StatefulWidget {
  const OfferEditorPage({
    super.key,
    required this.repository,
    this.offerId,
  });

  final AppRepository repository;
  final String? offerId;

  @override
  State<OfferEditorPage> createState() => _OfferEditorPageState();
}

class _OfferEditorPageState extends State<OfferEditorPage> {
  bool _loading = true;
  String? _offerId;
  String? _offerNumber;
  String _offerDate = DateTime.now().toIso8601String().split('T').first;
  String? _clientId;
  String _currency = 'RON';
  String _overheadMode = overheadModePercent;
  String _documentType = 'OFERTA_CLIENT';
  String? _logoBase64;
  String _lastSavedSignature = '';

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> _materials = [];
  List<EmployeeRecord> _employees = [];
  List<VehicleRecord> _vehicles = [];
  List<DraftMaterialLine> _lines = [];
  List<OfferEmployeeAssignment> _employeeAssignments = [];
  List<OfferVehicleAssignment> _vehicleAssignments = [];
  OverheadSettings _overheadSettings = const OverheadSettings();

  late final TextEditingController _eurRate;
  late final TextEditingController _vatPercent;
  late final TextEditingController _profitPercent;
  late final TextEditingController _overheadPercent;
  late final TextEditingController _notes;
  late final TextEditingController _companyName;
  late final TextEditingController _companyAddress;
  late final TextEditingController _companyPhone;
  late final TextEditingController _companyEmail;
  late final TextEditingController _companyCui;
  late final TextEditingController _companyTradeRegister;
  late final TextEditingController _companyBank;
  late final TextEditingController _companyIban;
  late final TextEditingController _companyContactName;
  late final TextEditingController _offerTitle;
  late final TextEditingController _workLocation;

  @override
  void initState() {
    super.initState();
    _offerId = widget.offerId;
    _eurRate = TextEditingController(text: '5.00');
    _vatPercent = TextEditingController(text: '21');
    _profitPercent = TextEditingController(text: '15');
    _overheadPercent = TextEditingController(text: '0');
    _notes = TextEditingController();
    _companyName = TextEditingController();
    _companyAddress = TextEditingController();
    _companyPhone = TextEditingController();
    _companyEmail = TextEditingController();
    _companyCui = TextEditingController();
    _companyTradeRegister = TextEditingController();
    _companyBank = TextEditingController();
    _companyIban = TextEditingController();
    _companyContactName = TextEditingController();
    _offerTitle = TextEditingController();
    _workLocation = TextEditingController();
    _load();
  }

  Future<void> _load() async {
    final results = await Future.wait([
      widget.repository.listClients(),
      widget.repository.listEmployees(activeOnly: true),
      widget.repository.listVehicles(activeOnly: true),
      widget.repository.getCompanySettings(),
      widget.repository.getOverheadSettings(),
      widget.repository.listMaterials(),
    ]);

    _clients = results[0] as List<Map<String, dynamic>>;
    _employees = results[1] as List<EmployeeRecord>;
    _vehicles = results[2] as List<VehicleRecord>;
    final companyDefaults = results[3] as CompanySettings;
    _overheadSettings = results[4] as OverheadSettings;
    _materials = results[5] as List<Map<String, dynamic>>;
    debugPrint(
      '[OfferEditor] loaded clients: ${_clients.length} using query table=clients eq user_id=$localUserId order=name',
    );
    for (final item in _clients) {
      debugPrint(
        '[OfferEditor] client item: id=${item['id']}, name=${item['name']}, phone=${item['phone']}, contact=${item['contact_person']}',
      );
    }
    debugPrint('OfferEditor loaded materials count: ${_materials.length}');

    if (_offerId != null) {
      final bundle = await widget.repository.loadOfferBundle(_offerId!);
      if (bundle != null) {
        final offer = bundle.offer;
        _offerNumber = valueText(offer['number']);
        _offerDate = valueText(offer['offer_date'], fallback: _offerDate);
        _documentType = _resolveDropdownValue(
              valueText(offer['document_type'], fallback: 'OFERTA_CLIENT'),
              _documentTypeDropdownOptions,
              fallback: 'OFERTA_CLIENT',
            ) ??
            'OFERTA_CLIENT';
        _offerTitle.text = valueText(offer['titlu_oferta']);
        _workLocation.text = valueText(offer['locatie_lucrare']);
        _clientId = _resolveDropdownValue(
          offer['client_id'] as String?,
          _clientDropdownOptions(_clients),
        );
        _currency = _resolveDropdownValue(
              valueText(offer['currency'], fallback: 'RON'),
              _currencyDropdownOptions,
              fallback: 'RON',
            ) ??
            'RON';
        _eurRate.text =
            parseDouble(offer['eur_rate'], fallback: 5).toStringAsFixed(2);
        _vatPercent.text =
            parseDouble(offer['vat_percent'], fallback: 21).toStringAsFixed(2);
        _profitPercent.text = parseDouble(offer['profit_percent'], fallback: 15)
            .toStringAsFixed(2);
        _overheadMode = _resolveDropdownValue(
              valueText(offer['overhead_mode'], fallback: overheadModePercent),
              _overheadModeDropdownOptions,
              fallback: overheadModePercent,
            ) ??
            overheadModePercent;
        _overheadPercent.text =
            parseDouble(offer['overhead_percent']).toStringAsFixed(2);
        _notes.text = valueText(offer['notes']);
        debugPrint('OfferEditor selected client id: $_clientId');
        final company = CompanySettings.fromMap(offer);
        _applyCompany(company);
        _lines = bundle.lines;
        _employeeAssignments = bundle.employeeAssignments;
        _vehicleAssignments = bundle.vehicleAssignments;
      }
    } else {
      _clientId = _resolveDropdownValue(
        _clientId,
        _clientDropdownOptions(_clients),
      );
      debugPrint('OfferEditor selected client id: $_clientId');
      _currency = _resolveDropdownValue(
            companyDefaults.defaultCurrency,
            _currencyDropdownOptions,
            fallback: 'RON',
          ) ??
          'RON';
      _vatPercent.text = companyDefaults.defaultVatPercent.toStringAsFixed(2);
      _profitPercent.text =
          companyDefaults.defaultProfitPercent.toStringAsFixed(2);
      _overheadMode = _resolveDropdownValue(
            _overheadSettings.defaultOverheadMode,
            _overheadModeDropdownOptions,
            fallback: overheadModePercent,
          ) ??
          overheadModePercent;
      final defaultOverhead = _overheadSettings.defaultOverheadPercent > 0
          ? _overheadSettings.defaultOverheadPercent
          : companyDefaults.defaultOverheadPercent;
      _overheadPercent.text = defaultOverhead.toStringAsFixed(2);
      _applyCompany(companyDefaults);
    }

    if (!mounted) {
      return;
    }
    _lastSavedSignature = _buildOfferSignature();
    setState(() => _loading = false);
  }

  void _applyCompany(CompanySettings settings) {
    _companyName.text = settings.companyName;
    _eurRate.text = settings.defaultEurRate.toStringAsFixed(2);
    _companyAddress.text = settings.companyAddress;
    _companyPhone.text = settings.companyPhone;
    _companyEmail.text = settings.companyEmail;
    _companyCui.text = settings.companyCui;
    _companyTradeRegister.text = settings.companyTradeRegister;
    _companyBank.text = settings.companyBank;
    _companyIban.text = settings.companyIban;
    _companyContactName.text = settings.companyContactName;
    _logoBase64 = settings.companyLogoBase64;
  }

  CompanySettings _currentCompany() {
    return CompanySettings(
      companyName: _companyName.text.trim(),
      companyAddress: _companyAddress.text.trim(),
      companyPhone: _companyPhone.text.trim(),
      companyEmail: _companyEmail.text.trim(),
      companyCui: _companyCui.text.trim(),
      companyTradeRegister: _companyTradeRegister.text.trim(),
      companyBank: _companyBank.text.trim(),
      companyIban: _companyIban.text.trim(),
      companyContactName: _companyContactName.text.trim(),
      companyLogoBase64: _logoBase64,
      defaultCurrency: _resolveDropdownValue(
              _currency, _currencyDropdownOptions,
              fallback: 'RON') ??
          'RON',
      defaultVatPercent: parseDouble(_vatPercent.text),
      defaultProfitPercent: parseDouble(_profitPercent.text),
      defaultOverheadPercent: parseDouble(_overheadPercent.text),
    );
  }

  OfferCalculations get _calculations => OfferCalculations.compute(
        lines: _lines,
        employees: _employeeAssignments,
        vehicles: _vehicleAssignments,
        overheadMode: _overheadMode,
        overheadPercent: parseDouble(_overheadPercent.text),
        overheadSettings: _overheadSettings,
        profitPercent: parseDouble(_profitPercent.text),
        vatPercent: parseDouble(_vatPercent.text),
      );

  String _buildOfferSignature() {
    final payload = {
      'offer_id': _offerId,
      'offer_number': _offerNumber,
      'offer_date': _offerDate,
      'document_type': _documentType,
      'offer_title': _offerTitle.text.trim(),
      'work_location': _workLocation.text.trim(),
      'client_id': _clientId,
      'currency': _currency,
      'eur_rate': _eurRate.text.trim(),
      'vat_percent': _vatPercent.text.trim(),
      'profit_percent': _profitPercent.text.trim(),
      'overhead_mode': _overheadMode,
      'overhead_percent': _overheadPercent.text.trim(),
      'notes': _notes.text.trim(),
      'company_name': _companyName.text.trim(),
      'company_address': _companyAddress.text.trim(),
      'company_phone': _companyPhone.text.trim(),
      'company_email': _companyEmail.text.trim(),
      'company_cui': _companyCui.text.trim(),
      'company_trade_register': _companyTradeRegister.text.trim(),
      'company_bank': _companyBank.text.trim(),
      'company_iban': _companyIban.text.trim(),
      'company_contact_name': _companyContactName.text.trim(),
      'logo_base64': _logoBase64,
      'lines': _lines.map((item) => item.toMap()).toList(),
      'employees': _employeeAssignments.map((item) => item.toMap()).toList(),
      'vehicles': _vehicleAssignments.map((item) => item.toMap()).toList(),
    };
    return jsonEncode(payload);
  }

  bool get _hasUnsavedChanges => _buildOfferSignature() != _lastSavedSignature;

  Future<bool> _confirmDiscardIfNeeded() async {
    if (!_hasUnsavedChanges) {
      return true;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modificarile nu sunt salvate'),
        content: const Text(
          'Daca iesi acum, modificarile nesalvate se vor pierde. Vrei sa continui?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Continua editarea'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Paraseste fara salvare'),
          ),
        ],
      ),
    );
    return discard ?? false;
  }

  Future<void> _closeEditor() async {
    final canClose = await _confirmDiscardIfNeeded();
    if (!mounted || !canClose) {
      return;
    }
    Navigator.pop(context);
  }

  Future<void> _pickOfferLogo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      withData: true,
    );
    if (result == null || result.files.isEmpty) {
      return;
    }
    final bytes = result.files.single.bytes;
    if (bytes == null) {
      return;
    }
    setState(() {
      _logoBase64 = base64Encode(bytes);
    });
  }

  Future<void> _saveOffer({bool closeAfterSave = false}) async {
    final sanitizedClientId = _resolveDropdownValue(
      _clientId,
      _clientDropdownOptions(_clients),
    );
    final sanitizedCurrency = _resolveDropdownValue(
            _currency, _currencyDropdownOptions,
            fallback: 'RON') ??
        'RON';
    final sanitizedOverheadMode = _resolveDropdownValue(
          _overheadMode,
          _overheadModeDropdownOptions,
          fallback: overheadModePercent,
        ) ??
        overheadModePercent;
    final savedId = await widget.repository.saveOffer(
      offerId: _offerId,
      offerNumber: _offerNumber,
      offerDate: _offerDate,
      documentType: _documentType,
      offerTitle: _offerTitle.text.trim(),
      workLocation: _workLocation.text.trim(),
      clientId: sanitizedClientId,
      currency: sanitizedCurrency,
      eurRate: parseDouble(_eurRate.text, fallback: 5),
      vatPercent: parseDouble(_vatPercent.text),
      profitPercent: parseDouble(_profitPercent.text),
      overheadMode: sanitizedOverheadMode,
      overheadPercent: parseDouble(_overheadPercent.text),
      companySnapshot: _currentCompany(),
      notes: _notes.text.trim(),
      lines: _lines,
      employees: _employeeAssignments,
      vehicles: _vehicleAssignments,
      calculations: _calculations,
    );
    _offerId = savedId;
    _clientId = sanitizedClientId;
    _currency = sanitizedCurrency;
    _overheadMode = sanitizedOverheadMode;
    final bundle = await widget.repository.loadOfferBundle(savedId);
    if (bundle != null) {
      final docType =
          valueText(bundle.offer['document_type']).trim().toUpperCase();
      final registryType = docType == 'DEVIZ_INTERN' ? 'deviz' : 'oferta';
      final allocatedNumber = await RegistryStore.allocateNumber(
        type: registryType,
        existingNumber: valueText(bundle.offer['number']),
      );
      await RegistryStore.upsertEntry(
        type: registryType,
        number: allocatedNumber,
        title: valueText(bundle.offer['titlu_oferta']),
        documentDate: valueText(bundle.offer['offer_date']),
        status: '',
        clientName: valueText(bundle.offer['client_name']),
        jobCode: '',
        referenceId: valueText(bundle.offer['id'], fallback: savedId),
        filePath: '',
        source: 'offers',
      );
    }
    if (bundle != null) {
      _offerNumber = valueText(bundle.offer['number']);
    }
    _lastSavedSignature = _buildOfferSignature();
    if (!mounted) {
      return;
    }
    if (closeAfterSave) {
      Navigator.pop(context);
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Oferta a fost salvata local.')),
    );
    setState(() {});
  }

  Future<void> _addMaterialLine() async {
    final freshMaterials = await widget.repository.listMaterials();
    _materials = freshMaterials;
    debugPrint(
      '[OfferDialog] loaded: ${freshMaterials.length} using query table=materials eq user_id=$localUserId order=name',
    );
    for (final item in freshMaterials) {
      debugPrint(
        '[OfferDialog] item: id=${item['id']}, name=${item['name']}, unit=${item['unit']}, price=${item['sell_price']}',
      );
    }
    if (!mounted) {
      return;
    }

    final materialOptions = _materialDropdownOptions(freshMaterials);
    String? materialId;
    debugPrint('[OfferDialog] selected material id: $materialId');
    final quantity = TextEditingController(text: '1');

    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adauga material'),
          content: SizedBox(
            width: 420,
            child: materialOptions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Text('Nu exista materiale salvate.'),
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: materialId,
                        items: materialOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          debugPrint(
                              '[OfferDialog] selected material id: $value');
                          setDialogState(() => materialId = value);
                        },
                        decoration:
                            const InputDecoration(labelText: 'Material'),
                      ),
                      const SizedBox(height: 12),
                      AbsorbPointer(
                        absorbing: materialId == null,
                        child: Opacity(
                          opacity: materialId == null ? 0.6 : 1,
                          child: _numberField(quantity, 'Cantitate'),
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: materialId == null
                  ? null
                  : () {
                      final material = freshMaterials.firstWhere(
                        (item) =>
                            _normalizeDropdownValue(valueText(item['id'])) ==
                            _normalizeDropdownValue(materialId),
                      );
                      setState(() {
                        _lines = [
                          ..._lines,
                          DraftMaterialLine(
                            materialId: valueText(material['id']),
                            materialName: valueText(material['name']),
                            unit: valueText(material['unit']),
                            quantity: parseDouble(quantity.text, fallback: 1),
                            unitPrice: parseDouble(material['sell_price']),
                          ),
                        ];
                      });
                      Navigator.pop(context);
                    },
              child: const Text('Adauga'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editMaterialLine(int index) async {
    final line = _lines[index];
    final name = TextEditingController(text: line.materialName);
    final unit = TextEditingController(text: line.unit);
    final quantity =
        TextEditingController(text: line.quantity.toStringAsFixed(2));
    final price =
        TextEditingController(text: line.unitPrice.toStringAsFixed(2));

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Editeaza articol'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _textField(name, 'Denumire / descriere'),
              _textField(unit, 'UM'),
              _numberField(quantity, 'Cantitate'),
              _numberField(price, 'Pret unitar'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _lines[index] = DraftMaterialLine(
                  materialId: line.materialId,
                  materialName: name.text.trim(),
                  unit: unit.text.trim(),
                  quantity: parseDouble(quantity.text, fallback: 1),
                  unitPrice: parseDouble(price.text),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
  }

  Future<void> _addEmployeeAssignment() async {
    final available = _employees
        .where(
          (employee) => !_employeeAssignments
              .any((item) => item.employeeId == employee.id),
        )
        .toList();
    final employeeOptions = _employeeDropdownOptions(available);
    if (employeeOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nu exista angajati activi disponibili.')),
      );
      return;
    }

    String? employeeId = _resolveDropdownValue(
      employeeOptions.first.value,
      employeeOptions,
      useFirstValid: true,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adauga angajat'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              initialValue: employeeId,
              items: employeeOptions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => employeeId = value),
              decoration: const InputDecoration(labelText: 'Angajat'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () {
                final employee =
                    available.firstWhere((item) => item.id == employeeId);
                setState(() {
                  _employeeAssignments = [
                    ..._employeeAssignments,
                    OfferEmployeeAssignment.fromEmployee(employee),
                  ];
                });
                Navigator.pop(context);
              },
              child: const Text('Adauga'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editEmployeeAssignment(int index) async {
    final item = _employeeAssignments[index];
    final hourlyRate = TextEditingController(
      text: item.hourlyRate.toStringAsFixed(2),
    );
    final hours =
        TextEditingController(text: item.workedHours.toStringAsFixed(2));
    final days =
        TextEditingController(text: item.workedDays.toStringAsFixed(2));
    final perDiem =
        TextEditingController(text: item.perDiemPerDay.toStringAsFixed(2));
    final lodging =
        TextEditingController(text: item.lodgingPerDay.toStringAsFixed(2));

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editeaza ${item.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField(hourlyRate, 'Tarif/h'),
              _numberField(hours, 'Ore lucrate'),
              _numberField(days, 'Zile lucrate'),
              _numberField(perDiem, 'Diurna/zi'),
              _numberField(lodging, 'Cazare/zi'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _employeeAssignments[index] = item.copyWith(
                  hourlyRate: parseDouble(hourlyRate.text),
                  workedHours: parseDouble(hours.text),
                  workedDays: parseDouble(days.text),
                  perDiemPerDay: parseDouble(perDiem.text),
                  lodgingPerDay: parseDouble(lodging.text),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
  }

  Future<void> _addVehicleAssignment() async {
    final available = _vehicles
        .where(
          (vehicle) =>
              !_vehicleAssignments.any((item) => item.vehicleId == vehicle.id),
        )
        .toList();
    final vehicleOptions = _vehicleDropdownOptions(available);
    if (vehicleOptions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nu exista autoturisme active disponibile.'),
        ),
      );
      return;
    }

    String? vehicleId = _resolveDropdownValue(
      vehicleOptions.first.value,
      vehicleOptions,
      useFirstValid: true,
    );
    await showDialog<void>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Adauga autoturism'),
          content: SizedBox(
            width: 420,
            child: DropdownButtonFormField<String>(
              initialValue: vehicleId,
              items: vehicleOptions
                  .map(
                    (item) => DropdownMenuItem(
                      value: item.value,
                      child: Text(item.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setDialogState(() => vehicleId = value),
              decoration: const InputDecoration(labelText: 'Autoturism'),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Anulează'),
            ),
            FilledButton(
              onPressed: () {
                final vehicle =
                    available.firstWhere((item) => item.id == vehicleId);
                setState(() {
                  _vehicleAssignments = [
                    ..._vehicleAssignments,
                    OfferVehicleAssignment.fromVehicle(vehicle),
                  ];
                });
                Navigator.pop(context);
              },
              child: const Text('Adauga'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editVehicleAssignment(int index) async {
    final item = _vehicleAssignments[index];
    final costPerKm = TextEditingController(
      text: item.costPerKm.toStringAsFixed(2),
    );
    final fixedDaily = TextEditingController(
      text: item.fixedDailyCost.toStringAsFixed(2),
    );
    final kilometers =
        TextEditingController(text: item.kilometers.toStringAsFixed(2));
    final days =
        TextEditingController(text: item.workedDays.toStringAsFixed(2));

    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Editeaza ${item.name}'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField(costPerKm, 'Cost/km'),
              _numberField(fixedDaily, 'Cost fix/zi'),
              _numberField(kilometers, 'Km'),
              _numberField(days, 'Zile'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          FilledButton(
            onPressed: () {
              setState(() {
                _vehicleAssignments[index] = item.copyWith(
                  costPerKm: parseDouble(costPerKm.text),
                  fixedDailyCost: parseDouble(fixedDaily.text),
                  kilometers: parseDouble(kilometers.text),
                  workedDays: parseDouble(days.text),
                );
              });
              Navigator.pop(context);
            },
            child: const Text('Salveaza'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportPdf() async {
    final documentLabel = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tip document'),
        content: const Text('Alege tipul documentului exportat.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Anulează'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 'OFERTA_CLIENT'),
            child: const Text('Ofertă client'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'DEVIZ_INTERN'),
            child: const Text('Deviz intern'),
          ),
        ],
      ),
    );
    if (documentLabel == null) {
      return;
    }
    setState(() {
      _documentType = documentLabel;
    });
    await _saveOffer(closeAfterSave: false);
    if (_offerId == null) {
      return;
    }
    final bundle = await widget.repository.loadOfferBundle(_offerId!);
    if (bundle == null || !mounted) {
      return;
    }
    final pdfService = PdfService();
    final pdf = await pdfService.buildOfferPdf(
      offer: bundle.offer,
      lines: bundle.lines,
      employees: bundle.employeeAssignments,
      vehicles: bundle.vehicleAssignments,
      company: CompanySettings.fromMap(bundle.offer),
      documentLabel: documentLabel,
    );
    final fileName =
        '${documentLabel == 'OFERTA_CLIENT' ? 'OFERTA_CLIENT' : 'DEVIZ_INTERN'}_${valueText(bundle.offer['number'], fallback: 'document').replaceAll(RegExp(r'[\\/:*?"<>|]'), '-').trim()}.pdf';
    final savedPath =
        await pdfService.exportPdf(bytes: pdf, filename: fileName);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('PDF exportat: $savedPath')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final calculations = _calculations;
    final displayRate = parseDouble(_eurRate.text, fallback: 5);
    final clientOptions = _clientDropdownOptions(_clients);
    final selectedClientId = _resolveDropdownValue(_clientId, clientOptions);
    final selectedCurrency = _resolveDropdownValue(
            _currency, _currencyDropdownOptions,
            fallback: 'RON') ??
        'RON';
    final selectedOverheadMode = _resolveDropdownValue(
          _overheadMode,
          _overheadModeDropdownOptions,
          fallback: overheadModePercent,
        ) ??
        overheadModePercent;
    final selectedDocumentType = _resolveDropdownValue(
          _documentType,
          _documentTypeDropdownOptions,
          fallback: 'OFERTA_CLIENT',
        ) ??
        'OFERTA_CLIENT';

    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) async {
          if (didPop) return;
          final canClose = await _confirmDiscardIfNeeded();
          if (!mounted) return;
          if (canClose && context.mounted) {
            Navigator.of(context).pop();
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: Text(_offerId == null ? 'Oferta noua' : 'Editeaza oferta'),
            actions: [
              if (_hasUnsavedChanges)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: Text(
                      'Modificari nesalvate',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              TextButton.icon(
                onPressed: _exportPdf,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('Exporta PDF'),
              ),
              const SizedBox(width: 12),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(24),
            child: ListView(
              children: [
                if (_offerNumber != null) ...[
                  Wrap(
                    spacing: 24,
                    children: [
                      Text(
                        'Numar: $_offerNumber',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text('Data: $_offerDate'),
                      if (_offerTitle.text.trim().isNotEmpty)
                        Text('Titlu ofertă: ${_offerTitle.text.trim()}'),
                      if (_workLocation.text.trim().isNotEmpty)
                        Text('Locație lucrare: ${_workLocation.text.trim()}'),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 420,
                      child: _textField(_offerTitle, 'Titlu ofertă'),
                    ),
                    SizedBox(
                      width: 420,
                      child: _textField(
                        _workLocation,
                        'Locație lucrare / obiectiv',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: 320,
                      child: clientOptions.isEmpty
                          ? const InputDecorator(
                              decoration: InputDecoration(labelText: 'Client'),
                              child: Text('Nu exista clienti salvati.'),
                            )
                          : DropdownButtonFormField<String>(
                              initialValue: selectedClientId,
                              items: clientOptions
                                  .map(
                                    (item) => DropdownMenuItem(
                                      value: item.value,
                                      child: Text(item.label),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (value) {
                                debugPrint(
                                    'OfferEditor selected client id: $value');
                                setState(() => _clientId = value);
                              },
                              decoration:
                                  const InputDecoration(labelText: 'Client'),
                            ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedDocumentType,
                        items: _documentTypeDropdownOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _documentType = value ?? 'OFERTA_CLIENT',
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Tip document'),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedCurrency,
                        items: _currencyDropdownOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) =>
                            setState(() => _currency = value ?? 'RON'),
                        decoration: const InputDecoration(labelText: 'Moneda'),
                      ),
                    ),
                    SizedBox(
                        width: 140, child: _numberField(_eurRate, 'Curs EUR')),
                    SizedBox(
                      width: 140,
                      child: _numberField(
                        _vatPercent,
                        'TVA %',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: _numberField(
                        _profitPercent,
                        'Profit %',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 180,
                      child: DropdownButtonFormField<String>(
                        initialValue: selectedOverheadMode,
                        items: _overheadModeDropdownOptions
                            .map(
                              (item) => DropdownMenuItem(
                                value: item.value,
                                child: Text(item.label),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(
                          () => _overheadMode = value ?? overheadModePercent,
                        ),
                        decoration:
                            const InputDecoration(labelText: 'Mod regie'),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: _numberField(
                        _overheadPercent,
                        'Regie %',
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                _numberField(_eurRate, 'Curs EUR implicit'),
                const SizedBox(height: 24),
                const Text(
                  'Date firma in oferta',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                        width: 320,
                        child: _textField(_companyName, 'Nume firma')),
                    SizedBox(
                        width: 260,
                        child: _textField(_companyPhone, 'Telefon')),
                    SizedBox(
                        width: 320, child: _textField(_companyEmail, 'Email')),
                    SizedBox(width: 220, child: _textField(_companyCui, 'CUI')),
                    SizedBox(
                      width: 260,
                      child: _textField(
                        _companyTradeRegister,
                        'Nr. registrul comertului',
                      ),
                    ),
                    SizedBox(
                        width: 260, child: _textField(_companyBank, 'Banca')),
                    SizedBox(
                        width: 320, child: _textField(_companyIban, 'IBAN')),
                    SizedBox(
                      width: 260,
                      child:
                          _textField(_companyContactName, 'Persoana contact'),
                    ),
                    SizedBox(
                      width: 620,
                      child: TextField(
                        controller: _companyAddress,
                        maxLines: 2,
                        decoration: const InputDecoration(labelText: 'Adresa'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _pickOfferLogo,
                      icon: const Icon(Icons.image_outlined),
                      label: Text(
                          _logoBase64 == null ? 'Alege logo' : 'Schimba logo'),
                    ),
                    if (_logoBase64 != null)
                      TextButton(
                        onPressed: () => setState(() => _logoBase64 = null),
                        child: const Text('Șterge logo'),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _notes,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Observatii'),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Materiale',
                  action: FilledButton.icon(
                    onPressed: _addMaterialLine,
                    icon: const Icon(Icons.add),
                    label: const Text('Adauga material'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Material')),
                        DataColumn(label: Text('UM')),
                        DataColumn(label: Text('Cant.')),
                        DataColumn(label: Text('Pret')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Actiuni')),
                      ],
                      rows: _lines
                          .asMap()
                          .entries
                          .map(
                            (entry) => DataRow(
                              cells: [
                                DataCell(Text(entry.value.materialName)),
                                DataCell(Text(entry.value.unit)),
                                DataCell(Text(
                                    entry.value.quantity.toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.unitPrice,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.total,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _editMaterialLine(entry.key),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                          () => _lines = List.of(_lines)
                                            ..removeAt(entry.key),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Angajati alocati',
                  action: FilledButton.icon(
                    onPressed: _addEmployeeAssignment,
                    icon: const Icon(Icons.add),
                    label: const Text('Adauga angajat'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Nume')),
                        DataColumn(label: Text('Rol')),
                        DataColumn(label: Text('Tarif/h')),
                        DataColumn(label: Text('Ore')),
                        DataColumn(label: Text('Zile')),
                        DataColumn(label: Text('Diurna/zi')),
                        DataColumn(label: Text('Cazare/zi')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Actiuni')),
                      ],
                      rows: _employeeAssignments
                          .asMap()
                          .entries
                          .map(
                            (entry) => DataRow(
                              cells: [
                                DataCell(Text(entry.value.name)),
                                DataCell(Text(entry.value.role)),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.hourlyRate,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(Text(entry.value.workedHours
                                    .toStringAsFixed(2))),
                                DataCell(Text(
                                    entry.value.workedDays.toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.perDiemPerDay,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.lodgingPerDay,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.laborCost,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _editEmployeeAssignment(entry.key),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                          () => _employeeAssignments =
                                              List.of(_employeeAssignments)
                                                ..removeAt(entry.key),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                _SectionHeader(
                  title: 'Autoturisme alocate',
                  action: FilledButton.icon(
                    onPressed: _addVehicleAssignment,
                    icon: const Icon(Icons.add),
                    label: const Text('Adauga autoturism'),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columns: const [
                        DataColumn(label: Text('Masina')),
                        DataColumn(label: Text('Nr.')),
                        DataColumn(label: Text('Cost/km')),
                        DataColumn(label: Text('Cost fix/zi')),
                        DataColumn(label: Text('Km')),
                        DataColumn(label: Text('Zile')),
                        DataColumn(label: Text('Total')),
                        DataColumn(label: Text('Actiuni')),
                      ],
                      rows: _vehicleAssignments
                          .asMap()
                          .entries
                          .map(
                            (entry) => DataRow(
                              cells: [
                                DataCell(Text(entry.value.name)),
                                DataCell(Text(entry.value.plateNumber)),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.costPerKm,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.fixedDailyCost,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(Text(
                                    entry.value.kilometers.toStringAsFixed(2))),
                                DataCell(Text(
                                    entry.value.workedDays.toStringAsFixed(2))),
                                DataCell(
                                  Text(
                                    formatMoney(
                                      entry.value.totalCost,
                                      currency: selectedCurrency,
                                      eurRate: displayRate,
                                    ),
                                  ),
                                ),
                                DataCell(
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        onPressed: () =>
                                            _editVehicleAssignment(entry.key),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                      IconButton(
                                        onPressed: () => setState(
                                          () => _vehicleAssignments =
                                              List.of(_vehicleAssignments)
                                                ..removeAt(entry.key),
                                        ),
                                        icon: const Icon(Icons.delete_outline),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Calcul',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _StatCard(
                      title: 'Materiale',
                      value: formatMoney(
                        calculations.materialsTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Manopera',
                      value: formatMoney(
                        calculations.laborTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Autoturisme',
                      value: formatMoney(
                        calculations.vehicleTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Direct',
                      value: formatMoney(
                        calculations.directTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Regie',
                      value: formatMoney(
                        calculations.overheadTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Profit',
                      value: formatMoney(
                        calculations.profitTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'TVA',
                      value: formatMoney(
                        calculations.vatTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Fara TVA',
                      value: formatMoney(
                        calculations.totalWithoutVat,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Total final',
                      value: formatMoney(
                        calculations.grandTotal,
                        currency: selectedCurrency,
                        eurRate: displayRate,
                      ),
                    ),
                    _StatCard(
                      title: 'Zile proiect',
                      value: calculations.projectDays.toStringAsFixed(2),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: _closeEditor,
                      child: const Text('Anulează'),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.icon(
                      onPressed: () => _saveOffer(closeAfterSave: false),
                      icon: const Icon(Icons.save),
                      label: Text(
                        _offerId == null
                            ? 'Salveaza oferta'
                            : 'Salveaza modificarile',
                      ),
                    ),
                    const SizedBox(width: 12),
                    FilledButton.tonalIcon(
                      onPressed: () => _saveOffer(closeAfterSave: true),
                      icon: const Icon(Icons.check),
                      label: const Text('Salvează și închide'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ));
  }
}

class _PageShell extends StatelessWidget {
  const _PageShell({
    required this.title,
    required this.child,
    this.action,
  });

  final String title;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              if (action != null) action!,
            ],
          ),
          const SizedBox(height: 16),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.action,
  });

  final String title;
  final Widget action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        action,
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.black54)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _textField(TextEditingController controller, String label) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
  );
}

Widget _numberField(
  TextEditingController controller,
  String label, {
  ValueChanged<String>? onChanged,
}) {
  return TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged,
  );
}

class _DropdownOption {
  const _DropdownOption({
    required this.value,
    required this.label,
  });

  final String value;
  final String label;
}

String? _normalizeDropdownValue(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }
  return normalized;
}

List<_DropdownOption> _uniqueDropdownOptions(Iterable<_DropdownOption> raw) {
  final seen = <String>{};
  final result = <_DropdownOption>[];
  for (final option in raw) {
    final value = _normalizeDropdownValue(option.value);
    if (value == null || seen.contains(value)) {
      continue;
    }
    seen.add(value);
    result.add(
      _DropdownOption(
        value: value,
        label: option.label.trim().isEmpty ? value : option.label.trim(),
      ),
    );
  }
  return result;
}

String? _resolveDropdownValue(
  String? selected,
  List<_DropdownOption> options, {
  String? fallback,
  bool useFirstValid = false,
}) {
  final normalizedSelected = _normalizeDropdownValue(selected);
  final values = options.map((option) => option.value).toSet();
  if (normalizedSelected != null && values.contains(normalizedSelected)) {
    return normalizedSelected;
  }
  final normalizedFallback = _normalizeDropdownValue(fallback);
  if (normalizedFallback != null && values.contains(normalizedFallback)) {
    return normalizedFallback;
  }
  if (useFirstValid && options.isNotEmpty) {
    return options.first.value;
  }
  return null;
}

List<_DropdownOption> _clientDropdownOptions(
    List<Map<String, dynamic>> clients) {
  return _uniqueDropdownOptions(
    clients.map(
      (item) => _DropdownOption(
        value: valueText(item['id']),
        label: valueText(item['name'], fallback: valueText(item['id'])),
      ),
    ),
  );
}

List<_DropdownOption> _materialDropdownOptions(
  List<Map<String, dynamic>> materials,
) {
  return _uniqueDropdownOptions(
    materials.map(
      (item) => _DropdownOption(
        value: valueText(item['id']),
        label: valueText(item['name'], fallback: valueText(item['id'])),
      ),
    ),
  );
}

List<_DropdownOption> _employeeDropdownOptions(
  List<EmployeeRecord> employees,
) {
  return _uniqueDropdownOptions(
    employees.map(
      (item) => _DropdownOption(
        value: item.id,
        label: '${item.name} (${item.role})',
      ),
    ),
  );
}

List<_DropdownOption> _vehicleDropdownOptions(
  List<VehicleRecord> vehicles,
) {
  return _uniqueDropdownOptions(
    vehicles.map(
      (item) => _DropdownOption(
        value: item.id,
        label: '${item.name} (${item.plateNumber})',
      ),
    ),
  );
}

const List<_DropdownOption> _currencyDropdownOptions = [
  _DropdownOption(value: 'RON', label: 'RON'),
  _DropdownOption(value: 'EUR', label: 'EUR'),
  _DropdownOption(value: 'USD', label: 'USD'),
];

const List<_DropdownOption> _overheadModeDropdownOptions = [
  _DropdownOption(value: overheadModePercent, label: 'Regie %'),
  _DropdownOption(value: overheadModeCalculated, label: 'Regie calculata'),
];

const List<_DropdownOption> _documentTypeDropdownOptions = [
  _DropdownOption(value: 'OFERTA_CLIENT', label: 'OFERTĂ'),
  _DropdownOption(value: 'DEVIZ_INTERN', label: 'DEVIZ'),
];
