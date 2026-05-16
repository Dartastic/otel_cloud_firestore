// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

/// OpenTelemetry instrumentation for `package:cloud_firestore`.
///
/// Adds `tracedGet`, `tracedSet`, `tracedAdd`, `tracedUpdate`,
/// `tracedDelete`, and `tracedSnapshots` as extension methods on
/// the standard Firestore types, plus top-level
/// [tracedFirestoreTransaction] and [tracedFirestoreBatchCommit].
library;

export 'src/firestore_semantics.dart';
export 'src/firestore_suppression.dart';
export 'src/otel_firestore_extensions.dart';
