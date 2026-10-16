<!-- dartastic-header:start -->
# OpenTelemetry instrumentation for `cloud_firestore`

[![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![OpenTelemetry Specification](https://img.shields.io/badge/OpenTelemetry-Specification-blueviolet)](https://opentelemetry.io/docs/specs/otel/)

`otel_cloud_firestore` is an [OpenTelemetry](https://opentelemetry.io/) instrumentation for `cloud_firestore` that
easily adds standard observability to applications that use `cloud_firestore`.  This package depends on 
[dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api).

This package can be used with any OTel backend because it's compliant with the OpenTelemetry Specification.

This package supports Android, iOS, macOS, Web and Windows, for versions of `cloud_firestore` that support those platforms. It is WASM-ready.

This Apache-2.0 package is professionally maintained and supported with 💙 by Michael Bushe,
Dart and Flutter Maintainer at OpenTelemetry and the creator of [dartastic_opentelemetry](https://pub.dev/packages/dartastic_opentelemetry)
and [dartastic_opentelemetry_api](https://pub.dev/packages/dartastic_opentelemetry_api). This package is professionally supported by
[Dartastic.io](https://dartastic.io).

---
## Dartastic.io: AI Code Healing and Real User Monitoring for Flutter

**See what your users experience. Find problems with Flutter apps in production. Fix them with AI.**

[Dartastic.io](https://dartastic.io) brings AI code healing, real user monitoring, and OpenTelemetry observability together in one platform built for Dart and Flutter. (Patents pending)

![Dartastic AI answering "Why did crashes jump after the last release?" over a Flutter App Health dashboard](https://dartastic.io/img/pub-dev/HomePageCrashesQuestion.png)

### Dartastic AI — From Production Problems to Code Fixes

Dartastic AI analyzes production telemetry alongside your application source code to diagnose problems and propose fixes.

- **Investigate production issues** using crashes, errors, traces, metrics, and real user telemetry.
- **Find the offending code** by connecting observed problems with your application's source in Dartastic Pub or your source code repos.
- **Generate code patches** that address the underlying problems.
- **Create actionable issues** in your issue tracker, complete with findings and the proposed code patch.

### Dartastic RUM — See What Your Users See

Understand how people actually experience your Flutter application.

- **Replay user sessions** in the Dartastic Observatory session player.
- **Choose your replay fidelity**, from privacy-preserving widget outlines to pixel-level reproductions of the user experience.
- **Investigate real user problems** using session replay and production observability data.

![Dartastic RUM Session Replay](https://dartastic.io/img/pub-dev/session-replay.png)

### Dartastic Observatory — Observability Built for Flutter

A complete observability backend where Flutter and Dart are first-class citizens.

- **Flutter-specific dashboards** for application performance, health, and reliability.
- **Alerts and notifications** through email, Slack, and PagerDuty.
- **Dartastic Cloud Observatory** — Start with a 30-day free trial on isolated, shared infrastructure, as low as $39/mo.
- **Dartastic Hosted Observatory** — Run the observability stack in a private managed environment, sized from Mini to Enterprise XL.
- **Dartastic Self-Hosted Observatory** — The whole platform inside your own network. Your keys, your cluster, with nothing leaving your perimeter.

### Dartastic Native OTel Runtime — Native OpenTelemetry Performance

Collect production telemetry without burdening Flutter's main isolate.

- **Native OpenTelemetry runtime** that moves telemetry processing off the main isolate.
- **Native crash reporting** for problems that Dart can't catch.
- **Widget performance diagnostics** to identify janky widgets.
- **On-device PII filtering** before sensitive data leaves your application.
- **Source-level error diagnostics** powered by the Dartastic Symbolizer API.
- **Platform-native metrics** for iOS, Android, and Linux, including iOS MetricKit and Android Vitals.
- **OpenTelemetry compatibility** — Send telemetry to Dartastic Observatory or any OpenTelemetry platform.

### Dartastic Labs — OpenTelemetry Integrations

Instrument more of your application without writing everything yourself.

- **650+ open-source integrations** for Dart and Flutter libraries and services, including Dio, Shelf, Logger, Anthropic, AWS, Azure, and Stripe. Look for otel_* on pub.dev.

### More Dartastic Tools

**[Dartastic Pub](https://dartastic.io/pub)**

A private Dart package registry for sharing packages and plugins with your team, partners, and customers.

**[Dartastic Symbolizer](https://dartastic.io/symbolizer)**

Turn production errors into lines of source code through a web API, while keeping your source code artifacts private.

### Professional Support and Training

Dartastic.io offers commercial support for the open-source `dartastic_opentelemetry` and `dartastic_opentelemetry_api` packages and the complete Dartastic product suite.

- **Professional support** with available around-the-clock coverage and response times under four hours on qualifying plans.
- **OpenTelemetry training** for teams instrumenting Dart, Flutter, mobile, and web applications.

### Open Standards. No Mandatory Backend.

The Dartastic OpenTelemetry API and SDK are open source and standards-based. You can use them independently of Dartastic's commercial services and send telemetry to any compatible OpenTelemetry backend.

Dartastic's commercial products add native performance, advanced diagnostics, session replay, AI-assisted remediation, and managed observability services.

**[Explore Dartastic.io](https://dartastic.io)**

---
<!-- dartastic-header:end -->

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

| Span name | `db.operation.name` | Other attributes |
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

Every span also carries `db.system.name=firestore` (the current
semconv key; the deprecated `db.system` is not emitted), and spans
with a known collection carry `db.collection.name`.

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
