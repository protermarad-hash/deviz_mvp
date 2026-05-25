import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/cloud/firebase_collections.dart';
import 'client_models.dart';
import 'clienti_cloud_repository.dart';

class FirebaseClientiRepository implements ClientiCloudRepository {
  FirebaseClientiRepository({
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection(FirebaseCollections.clients);

  @override
  Future<void> deleteClient(String clientId) async {
    final id = clientId.trim();
    if (id.isEmpty) return;
    await _collection.doc(id).delete();
  }

  @override
  Future<List<ClientRecord>> listClients() async {
    final snapshot = await _collection.get();
    return snapshot.docs
        .map((doc) => ClientRecord.fromMap(_normalizeClientMap(doc.data())))
        .where((item) => item.id.trim().isNotEmpty)
        .toList(growable: false);
  }

  @override
  Future<void> upsertClient(ClientRecord client) async {
    final id = client.id.trim();
    if (id.isEmpty) return;
    await _collection
        .doc(id)
        .set(_clientToCloudMap(client), SetOptions(merge: true));
  }

  @override
  Stream<List<ClientRecord>> watchClients() {
    return _collection.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ClientRecord.fromMap(_normalizeClientMap(doc.data())))
          .where((item) => item.id.trim().isNotEmpty)
          .toList(growable: false);
    });
  }

  Map<String, dynamic> _clientToCloudMap(ClientRecord item) {
    return <String, dynamic>{
      'id': item.id,
      'client_code': item.clientCode,
      'external_client_code': item.externalClientCode,
      'external_client_source': item.externalClientSource,
      'type': item.type.value,
      'name': item.name,
      'contact_person': item.contactPerson,
      'phone': item.phone,
      'phone2': item.phone2,
      'phone3': item.phone3,
      'email': item.email,
      'cui': item.cui,
      'reg_com': item.regCom,
      'iban': item.iban,
      'bank': item.bank,
      'departments':
          item.departments.map((department) => department.toMap()).toList(),
      'contact_people':
          item.contactPeople.map((contact) => contact.toMap()).toList(),
      'address': item.address,
      'city': item.city,
      'county': item.county,
      'notes': item.notes,
      'is_active': item.isActive,
      'created_at': item.createdAt.toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic> _normalizeClientMap(Map<String, dynamic> raw) {
    return <String, dynamic>{
      'id': (raw['id'] ?? '').toString(),
      'client_code':
          (raw['client_code'] ?? raw['clientCode'] ?? raw['code'] ?? '')
              .toString(),
      'external_client_code': (raw['external_client_code'] ??
              raw['externalClientCode'] ??
              raw['partner_client_code'] ??
              '')
          .toString(),
      'external_client_source': (raw['external_client_source'] ??
              raw['externalClientSource'] ??
              raw['partner_source'] ??
              '')
          .toString(),
      'type': (raw['type'] ?? raw['client_type'] ?? '').toString(),
      'name':
          (raw['name'] ?? raw['client_name'] ?? raw['company_name'] ?? '')
              .toString(),
      'contact_person': (raw['contact_person'] ??
              raw['contactPerson'] ??
              raw['contact_name'] ??
              '')
          .toString(),
      'phone': (raw['phone'] ?? '').toString(),
      'phone2': (raw['phone2'] ?? '').toString(),
      'phone3': (raw['phone3'] ?? '').toString(),
      'email': (raw['email'] ?? '').toString(),
      'cui': (raw['cui'] ?? '').toString(),
      'reg_com': (raw['reg_com'] ?? raw['regCom'] ?? '').toString(),
      'iban': (raw['iban'] ?? '').toString(),
      'bank': (raw['bank'] ?? '').toString(),
      'departments': raw['departments'] ?? raw['client_departments'],
      'contact_people':
          raw['contact_people'] ?? raw['contactPeople'] ?? raw['contacts'],
      'address': (raw['address'] ?? '').toString(),
      'city': (raw['city'] ?? '').toString(),
      'county': (raw['county'] ?? '').toString(),
      'notes': (raw['notes'] ?? '').toString(),
      'is_active': raw['is_active'] ?? raw['isActive'] ?? true,
      'created_at': (raw['created_at'] ?? raw['createdAt'] ?? '').toString(),
      'updated_at': (raw['updated_at'] ?? raw['updatedAt'] ?? '').toString(),
    };
  }
}
