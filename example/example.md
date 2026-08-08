# otel_cloud_firestore example

```dart
// example/lib/main.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartastic_opentelemetry/dartastic_opentelemetry.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:otel_cloud_firestore/otel_cloud_firestore.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. Bring up Firebase as usual.
  await Firebase.initializeApp();

  // 2. Bring up OTel before the first Firestore call so spans have
  //    somewhere to go.
  await OTel.initialize(
    serviceName: 'firestore-demo',
  );

  final db = FirebaseFirestore.instance;

  // ✨ Span: `firestore set users/alice`
  //    db.system.name=firestore, db.operation.name=set,
  //    db.collection.name=users, db.firestore.document=alice
  await db.collection('users').doc('alice').tracedSet({'name': 'Alice'});

  // ✨ Span: `firestore get users/alice`
  final snap = await db.collection('users').doc('alice').tracedGet();
  debugPrint('loaded: ${snap.data()}');

  // ✨ Span: `firestore add orders`
  await db.collection('orders').tracedAdd({'sku': 'ABC', 'qty': 2});

  // ✨ Span: `firestore query users` with db.response.returned_rows
  final adults = await db
      .collection('users')
      .where('age', isGreaterThan: 18)
      .tracedGet();
  debugPrint('${adults.docs.length} adults');

  // ✨ Span: `firestore transaction` with
  //    db.firestore.transaction.attempt
  final counter = db.collection('counters').doc('c1');
  await tracedFirestoreTransaction<int>(db, (txn) async {
    final s = await txn.get(counter);
    final next = ((s.data()?['n'] as int?) ?? 0) + 1;
    txn.set(counter, {'n': next});
    return next;
  });

  // ✨ Span: `firestore batch.commit` with db.firestore.batch.size
  final batch = db.batch();
  batch.set(db.collection('users').doc('a'), {'n': 1});
  batch.set(db.collection('users').doc('b'), {'n': 2});
  await tracedFirestoreBatchCommit(batch, size: 2);

  // Need a Firestore call to stay out of your traces (for example a
  // structured-log sink)? Suppress inside a zone:
  await runWithoutFirestoreInstrumentationAsync(() async {
    await db.collection('logs').add({'msg': 'no span for this write'});
  });

  runApp(const MaterialApp(home: Scaffold(body: Center(child: Text('ok')))));
}
```

## Trace shape

```
firestore set users/alice          CLIENT  db.operation.name=set
firestore get users/alice          CLIENT  db.operation.name=get
firestore add orders               CLIENT  db.operation.name=add
firestore query users              CLIENT  db.response.returned_rows=…
firestore transaction              CLIENT  db.firestore.transaction.attempt=1
firestore batch.commit             CLIENT  db.firestore.batch.size=2
```

Every span carries `db.system.name=firestore`; document and
collection spans also carry `db.collection.name` and the
`db.firestore.*` keys. Calls made inside
`Tracer.startActiveSpan` nest under the surrounding span.
