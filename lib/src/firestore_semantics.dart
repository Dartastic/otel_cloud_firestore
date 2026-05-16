// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry_api/dartastic_opentelemetry_api.dart';

/// Cloud Firestore-specific attribute keys.
///
/// These mirror the OTel semconv proposal for Firestore
/// (`db.firestore.*`). Held here because the API's general
/// `Database` enum doesn't yet carry the Firestore-specific keys;
/// once it does, this enum becomes a thin re-export.
enum FirestoreSemantics implements OTelSemantic {
  /// `db.firestore.collection` — the collection or sub-collection
  /// path the operation targeted. e.g. `users` or
  /// `users/abc123/orders`.
  collection('db.firestore.collection'),

  /// `db.firestore.document` — the document ID, when known.
  /// Absent for collection/query operations.
  document('db.firestore.document'),

  /// `db.firestore.transaction.attempt` — the 1-based attempt count
  /// for transactional operations (Firestore retries optimistic-lock
  /// failures internally).
  transactionAttempt('db.firestore.transaction.attempt'),

  /// `db.firestore.batch.size` — the number of writes batched in a
  /// `WriteBatch.commit()` call.
  batchSize('db.firestore.batch.size');

  @override
  final String key;

  @override
  String toString() => key;

  const FirestoreSemantics(this.key);
}
