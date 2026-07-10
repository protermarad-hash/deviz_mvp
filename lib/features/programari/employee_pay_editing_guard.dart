bool canDeleteMissingEmployeePayEntries({
  required bool isEditingExisting,
  required bool payEntriesLoadConclusive,
}) {
  return isEditingExisting && payEntriesLoadConclusive;
}
