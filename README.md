# otel_cloud_firestore

OpenTelemetry instrumentation for
[`package:cloud_firestore`](https://pub.dev/packages/cloud_firestore),
built on the
[Dartastic OpenTelemetry SDK](https://pub.dev/packages/dartastic_opentelemetry).

Adds `traced*` extension methods to the standard Firestore types
so every read, write, query, transaction, and batch commit emits a
`CLIENT` span carrying the OTel database (`db.*`) semconv attributes.

```dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:otel_cloud_firestore/otel_cloud_firestore.dart';

final db = FirebaseFirestore.instance;

// Document operations
await db.collection('users').doc('alice').tracedSet({'name': 'Alice'});
final snap = await db.collection('users').doc('alice').tracedGet();
await db.collection('users').doc('alice').tracedUpdate({'name': 'Alicia'});
await db.collection('users').doc('alice').tracedDelete();

// Collection operations
final ref = await db.collection('orders').tracedAdd({'sku': 'ABC', 'qty': 2});

// Queries
final query = await db
    .collection('users')
    .where('age', isGreaterThan: 18)
    .tracedGet();
// span attribute `db.response.returned_rows` reflects query.docs.length

// Transactions
final result = await tracedFirestoreTransaction(db, (txn) async {
  final snap = await txn.get(doc);
  final next = (snap.data()!['n'] as int) + 1;
  txn.update(doc, {'n': next});
  return next;
});

// Batch writes
final batch = db.batch();
batch.set(db.collection('users').doc('a'), {'n': 1});
batch.set(db.collection('users').doc('b'), {'n': 2});
await tracedFirestoreBatchCommit(batch, size: 2);
```

## Span shape

| Span name | `db.operation` | Other attributes |
|---|---|---|
| `firestore get <collection>/<doc>` | `get` | `db.firestore.collection`, `db.firestore.document` |
| `firestore set <collection>/<doc>` | `set` | `db.firestore.collection`, `db.firestore.document` |
| `firestore update <collection>/<doc>` | `update` | `db.firestore.collection`, `db.firestore.document` |
| `firestore delete <collection>/<doc>` | `delete` | `db.firestore.collection`, `db.firestore.document` |
| `firestore add <collection>` | `add` | `db.firestore.collection` |
| `firestore query <collection>` | `query` | `db.firestore.collection`, `db.response.returned_rows` |
| `firestore snapshots …` | `snapshots` | as for the subscribed type |
| `firestore transaction` | `transaction` | `db.firestore.transaction.attempt` (latest) |
| `firestore batch.commit` | `batch.commit` | `db.firestore.batch.size` (when supplied) |

Every span also carries `db.system=firestore` and (the current
semconv) `db.system.name=firestore`.

- **Span kind**: `CLIENT`.
- **Span status**: `Error` if the Firestore call throws.
  `error.type` is set to the exception's class name; the exception
  is recorded as an event, then status is set (OTel-spec order).
- Spans inherit the surrounding active span as parent, so
  Firestore calls inside `Tracer.startActiveSpan` nest naturally.

## Real-time listeners (`tracedSnapshots`)

`tracedSnapshots` emits a single short span at subscribe time —
no span per emission. Per-emission instrumentation would be far
too noisy for typical Firestore listeners; use `tracedGet` for
one-shot reads if you want a span per call.

## Self-recursion guard

`package:cloud_firestore` is not a Dartastic export transport
today, but the same suppression pattern as the other OSS wrappers
is present preemptively:

```dart
await runWithoutFirestoreInstrumentationAsync(() async {
  await db.collection('logs').add({'msg': 'foo'});
});
```

Inside the helper's zone, the `traced*` extension methods become
transparent passthroughs — the underlying Firestore call still
runs, but no span is opened. Safe to nest. Sync variant:
`runWithoutFirestoreInstrumentation`.

## Caveats

- `Query` doesn't expose its source collection path directly; for
  `where`/`orderBy`-chained queries, the `db.firestore.collection`
  attribute resolves to the parent `CollectionReference` path when
  detectable, otherwise it's omitted.
- The wrapper calls `OTel.tracerProvider().getTracer(...)` on each
  invocation — `OTel.initialize()` must have run first.
- `tracedSnapshots` does **not** instrument individual emissions.
  See above.

## License

Apache 2.0 — see `LICENSE`.
