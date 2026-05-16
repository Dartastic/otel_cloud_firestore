// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';

import 'firestore_semantics.dart';
import 'firestore_suppression.dart';

const _tracerName = 'otel_cloud_firestore';
const _dbSystem = 'firestore';

Tracer _tracer() => OTel.tracerProvider().getTracer(_tracerName);

Attributes _baseAttrs({
  required String operation,
  String? collection,
  String? document,
}) {
  final m = <String, Object>{
    Database.dbSystem.key: _dbSystem,
    Database.dbSystemName.key: _dbSystem,
    Database.dbOperation.key: operation,
    Database.dbOperationName.key: operation,
  };
  if (collection != null) {
    m[FirestoreSemantics.collection.key] = collection;
    m[Database.dbCollectionName.key] = collection;
  }
  if (document != null) m[FirestoreSemantics.document.key] = document;
  return OTel.attributesFromMap(m);
}

String _spanName(String operation, {String? collection, String? document}) {
  if (document != null && collection != null) {
    return 'firestore $operation $collection/$document';
  }
  if (collection != null) return 'firestore $operation $collection';
  return 'firestore $operation';
}

/// Runs [op] inside a CLIENT span carrying the standard `db.*`
/// attributes for a Firestore call. On exception: flips status to
/// Error in OTel-spec order (recordException → setStatus) and
/// rethrows. In a suppressed zone, calls [op] with `null` and emits
/// no span at all.
Future<R> _traced<R>(
  String operation, {
  required Future<R> Function(APISpan? span) op,
  String? collection,
  String? document,
}) async {
  if (firestoreInstrumentationSuppressed()) return op(null);
  final span = _tracer().startSpan(
    _spanName(operation, collection: collection, document: document),
    kind: SpanKind.client,
    attributes: _baseAttrs(
      operation: operation,
      collection: collection,
      document: document,
    ),
  );
  try {
    return await op(span);
  } catch (e, st) {
    span.addAttributes(OTel.attributes([
      OTel.attributeString(
        ErrorResource.errorType.key,
        e.runtimeType.toString(),
      ),
    ]));
    span.recordException(e, stackTrace: st);
    span.setStatus(SpanStatusCode.Error, e.toString());
    rethrow;
  } finally {
    span.end();
  }
}

/// Traced operations on a [DocumentReference].
///
/// Each call opens a `CLIENT` span named
/// `firestore <op> <collection>/<doc>` with `db.system=firestore`
/// and `db.firestore.collection` / `db.firestore.document`. On
/// exception the span is flipped to `Error` (recordException →
/// setStatus, in OTel-spec order) and the original error is
/// rethrown.
extension OTelDocumentReference<T> on DocumentReference<T> {
  /// Traced `get`.
  Future<DocumentSnapshot<T>> tracedGet([GetOptions? options]) {
    return _traced<DocumentSnapshot<T>>(
      'get',
      collection: parent.path,
      document: id,
      op: (_) => options == null ? get() : get(options),
    );
  }

  /// Traced `set`.
  Future<void> tracedSet(T data, [SetOptions? options]) {
    return _traced<void>(
      'set',
      collection: parent.path,
      document: id,
      op: (_) => options == null ? set(data) : set(data, options),
    );
  }

  /// Traced `update`.
  Future<void> tracedUpdate(Map<Object, Object?> data) {
    return _traced<void>(
      'update',
      collection: parent.path,
      document: id,
      op: (_) => update(data),
    );
  }

  /// Traced `delete`.
  Future<void> tracedDelete() {
    return _traced<void>(
      'delete',
      collection: parent.path,
      document: id,
      op: (_) => delete(),
    );
  }

  /// Traced `snapshots`. Emits a short span at subscribe time only;
  /// per-emission instrumentation is intentionally skipped to keep
  /// real-time listeners cheap. Use `tracedGet` for one-shot reads.
  Stream<DocumentSnapshot<T>> tracedSnapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (firestoreInstrumentationSuppressed()) {
      return snapshots(
        includeMetadataChanges: includeMetadataChanges,
        source: source,
      );
    }
    final span = _tracer().startSpan(
      _spanName('snapshots', collection: parent.path, document: id),
      kind: SpanKind.client,
      attributes: _baseAttrs(
        operation: 'snapshots',
        collection: parent.path,
        document: id,
      ),
    );
    span.end();
    return snapshots(
      includeMetadataChanges: includeMetadataChanges,
      source: source,
    );
  }
}

/// Traced `add` on a [CollectionReference]. Other inherited methods
/// come from the [OTelQuery] extension.
extension OTelCollectionReference<T> on CollectionReference<T> {
  /// Traced `add`.
  Future<DocumentReference<T>> tracedAdd(T data) {
    return _traced<DocumentReference<T>>(
      'add',
      collection: path,
      op: (_) => add(data),
    );
  }
}

/// Traced operations on a [Query] (including [CollectionReference],
/// which extends it).
extension OTelQuery<T> on Query<T> {
  /// Traced `get`. Adds `db.response.returned_rows` for the size of
  /// the returned snapshot.
  Future<QuerySnapshot<T>> tracedGet([GetOptions? options]) async {
    return _traced<QuerySnapshot<T>>(
      'query',
      collection: _pathFromQuery(this),
      op: (span) async {
        final snap = options == null ? await get() : await get(options);
        span?.addAttributes(OTel.attributes([
          OTel.attributeInt(
            Database.dbResponseReturnedRows.key,
            snap.docs.length,
          ),
        ]));
        return snap;
      },
    );
  }

  /// Traced `snapshots` (real-time listener). See
  /// [OTelDocumentReference.tracedSnapshots] for the per-emission
  /// rationale.
  Stream<QuerySnapshot<T>> tracedSnapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) {
    if (firestoreInstrumentationSuppressed()) {
      return snapshots(
        includeMetadataChanges: includeMetadataChanges,
        source: source,
      );
    }
    final span = _tracer().startSpan(
      _spanName('snapshots', collection: _pathFromQuery(this)),
      kind: SpanKind.client,
      attributes: _baseAttrs(
        operation: 'snapshots',
        collection: _pathFromQuery(this),
      ),
    );
    span.end();
    return snapshots(
      includeMetadataChanges: includeMetadataChanges,
      source: source,
    );
  }
}

/// `Query` doesn't expose its path directly, but `CollectionReference`
/// does. For arbitrary `Query` instances (post-`where` / `orderBy`),
/// best-effort fall back via the typed parameters object.
String? _pathFromQuery(Query<dynamic> q) {
  if (q is CollectionReference) return q.path;
  return null;
}

/// Traced wrapper for [FirebaseFirestore.runTransaction].
///
/// The span carries `db.operation=transaction` and (when Firestore
/// retries) the attempt count on
/// `db.firestore.transaction.attempt`.
Future<R> tracedFirestoreTransaction<R>(
  FirebaseFirestore db,
  TransactionHandler<R> handler, {
  Duration timeout = const Duration(seconds: 30),
  int maxAttempts = 5,
}) async {
  return _traced<R>(
    'transaction',
    op: (span) async {
      var attempt = 0;
      return db.runTransaction<R>(
        (txn) {
          attempt++;
          span?.addAttributes(OTel.attributes([
            OTel.attributeInt(
              FirestoreSemantics.transactionAttempt.key,
              attempt,
            ),
          ]));
          return handler(txn);
        },
        timeout: timeout,
        maxAttempts: maxAttempts,
      );
    },
  );
}

/// Traced wrapper for [WriteBatch.commit]. The span carries
/// `db.firestore.batch.size` when [size] is supplied.
Future<void> tracedFirestoreBatchCommit(
  WriteBatch batch, {
  int? size,
}) async {
  return _traced<void>(
    'batch.commit',
    op: (span) {
      if (size != null) {
        span?.addAttributes(OTel.attributes([
          OTel.attributeInt(FirestoreSemantics.batchSize.key, size),
        ]));
      }
      return batch.commit();
    },
  );
}
