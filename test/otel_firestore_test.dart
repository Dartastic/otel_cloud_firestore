// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:otel_cloud_firestore/otel_cloud_firestore.dart';

class _MemorySpanExporter implements SpanExporter {
  final List<Span> spans = [];
  bool _shutdown = false;

  @override
  Future<void> export(List<Span> s) async {
    if (_shutdown) return;
    spans.addAll(s);
  }

  @override
  Future<void> forceFlush() async {}

  @override
  Future<void> shutdown() async {
    _shutdown = true;
  }
}

Map<String, Object> _attrs(Span span) =>
    {for (final a in span.attributes.toList()) a.key: a.value};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OTel Firestore extensions', () {
    late _MemorySpanExporter exporter;
    late FakeFirebaseFirestore db;

    setUp(() async {
      await OTel.reset();
      exporter = _MemorySpanExporter();
      await OTel.initialize(
        serviceName: 'firestore-otel-test',
        detectPlatformResources: false,
        spanProcessor: SimpleSpanProcessor(exporter),
      );
      db = FakeFirebaseFirestore();
    });

    tearDown(() async {
      await OTel.shutdown();
      await OTel.reset();
    });

    test('tracedSet + tracedGet on a document emit db.* spans', () async {
      final doc = db.collection('users').doc('alice');
      await doc.tracedSet({'name': 'Alice'});
      final snap = await doc.tracedGet();

      expect(snap.data()?['name'], equals('Alice'));

      final setSpan = exporter.spans.firstWhere(
        (s) => s.name == 'firestore set users/alice',
      );
      expect(setSpan.kind, equals(SpanKind.client));
      final setAttrs = _attrs(setSpan);
      expect(setAttrs['db.system'], equals('firestore'));
      expect(setAttrs['db.system.name'], equals('firestore'));
      expect(setAttrs['db.operation'], equals('set'));
      expect(setAttrs['db.firestore.collection'], equals('users'));
      expect(setAttrs['db.firestore.document'], equals('alice'));

      final getSpan = exporter.spans.firstWhere(
        (s) => s.name == 'firestore get users/alice',
      );
      expect(_attrs(getSpan)['db.operation'], equals('get'));
      expect(setSpan.status, isNot(equals(SpanStatusCode.Error)));
    });

    test('tracedAdd on a CollectionReference emits an add span', () async {
      final ref =
          await db.collection('orders').tracedAdd({'sku': 'ABC', 'qty': 2});
      expect(ref.id, isNotEmpty);

      final span = exporter.spans.firstWhere(
        (s) => s.name == 'firestore add orders',
      );
      final attrs = _attrs(span);
      expect(attrs['db.operation'], equals('add'));
      expect(attrs['db.firestore.collection'], equals('orders'));
    });

    test('tracedGet on a Query records returned_rows', () async {
      await db.collection('users').add({'name': 'Alice', 'age': 30});
      await db.collection('users').add({'name': 'Bob', 'age': 40});

      final snap = await db.collection('users').tracedGet();
      expect(snap.docs.length, equals(2));

      final span = exporter.spans.firstWhere(
        (s) => s.name == 'firestore query users',
      );
      final attrs = _attrs(span);
      expect(attrs['db.operation'], equals('query'));
      expect(attrs['db.response.returned_rows'], equals(2));
    });

    test('tracedUpdate + tracedDelete emit their spans', () async {
      final doc = db.collection('users').doc('alice');
      await doc.set({'name': 'Alice'});

      await doc.tracedUpdate({'name': 'Alicia'});
      await doc.tracedDelete();

      expect(
        exporter.spans.any((s) => s.name == 'firestore update users/alice'),
        isTrue,
      );
      expect(
        exporter.spans.any((s) => s.name == 'firestore delete users/alice'),
        isTrue,
      );
    });

    test('exception flips span status to Error (recordException + setStatus)',
        () async {
      final doc = db.collection('users').doc('does-not-exist');
      // update() on a non-existent document throws in real Firestore.
      // fake_cloud_firestore mirrors this.
      await expectLater(
        doc.tracedUpdate({'name': 'ghost'}),
        throwsA(anything),
      );

      final span = exporter.spans.firstWhere(
        (s) => s.name == 'firestore update users/does-not-exist',
      );
      expect(span.status, equals(SpanStatusCode.Error));
      final events = span.spanEvents ?? [];
      expect(events.any((e) => e.name == 'exception'), isTrue);
      expect(_attrs(span).containsKey('error.type'), isTrue);
    });

    test('runWithoutFirestoreInstrumentationAsync bypasses span creation',
        () async {
      await runWithoutFirestoreInstrumentationAsync(() async {
        await db.collection('users').doc('alice').tracedSet({'name': 'A'});
      });

      expect(
        exporter.spans.where((s) => s.name.startsWith('firestore ')),
        isEmpty,
      );
    });

    test('tracedFirestoreTransaction emits a transaction span', () async {
      final doc = db.collection('counters').doc('c1');
      await doc.set({'n': 0});

      final result = await tracedFirestoreTransaction<int>(db, (txn) async {
        final snap = await txn.get(doc);
        final next = (snap.data()!['n'] as int) + 1;
        txn.update(doc, {'n': next});
        return next;
      });

      expect(result, equals(1));

      final span = exporter.spans.firstWhere(
        (s) => s.name == 'firestore transaction',
      );
      final attrs = _attrs(span);
      expect(attrs['db.operation'], equals('transaction'));
      expect(attrs['db.firestore.transaction.attempt'], equals(1));
    });

    test('tracedFirestoreBatchCommit records batch.size', () async {
      final batch = db.batch();
      batch.set(db.collection('users').doc('a'), {'n': 1});
      batch.set(db.collection('users').doc('b'), {'n': 2});

      await tracedFirestoreBatchCommit(batch, size: 2);

      final span = exporter.spans.firstWhere(
        (s) => s.name == 'firestore batch.commit',
      );
      expect(_attrs(span)['db.firestore.batch.size'], equals(2));
    });
  });
}
