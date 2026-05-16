# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0-beta.1-wip]

### Added

- Extension methods on `DocumentReference`:
  `tracedGet`, `tracedSet`, `tracedUpdate`, `tracedDelete`,
  `tracedSnapshots`. Each opens a `CLIENT` span named
  `firestore <op> <collection>/<doc>` with `db.system=firestore`
  and `db.firestore.collection` / `db.firestore.document`
  attributes.
- Extension method on `CollectionReference`: `tracedAdd`.
- Extension methods on `Query`: `tracedGet`, `tracedSnapshots`.
  `tracedGet` adds `db.response.returned_rows` for the snapshot
  size.
- Top-level `tracedFirestoreTransaction` — wraps
  `FirebaseFirestore.runTransaction` with an attempt counter
  surfaced as `db.firestore.transaction.attempt`.
- Top-level `tracedFirestoreBatchCommit` — wraps
  `WriteBatch.commit` and records `db.firestore.batch.size` when
  supplied.
- `runWithoutFirestoreInstrumentation` /
  `runWithoutFirestoreInstrumentationAsync` — zone-scoped
  suppression helpers, mirroring the pattern used by
  `dartastic_grpc_otel`, `dartastic_http_otel`, and
  `dartastic_web_socket_channel_otel`. Preemptive: Firestore is a
  plausible (if unconventional) log sink in some deployments.
- `FirestoreSemantics` — typed attribute-key enum holding the
  Firestore-specific `db.firestore.*` keys until the upstream
  semconv `Database` enum picks them up.
- Tests use `fake_cloud_firestore`; no live Firebase required.
  Coverage: doc set+get, collection add, query get with
  returned_rows, update + delete, exception path, suppression
  scope, transaction (with attempt counter), batch commit
  (with size).
