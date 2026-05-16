// Licensed under the Apache License, Version 2.0
// Copyright 2025, Mindful Software LLC, All rights reserved.

import 'dart:async';

/// Zone key used to mark a region of code as "do not instrument
/// Firestore calls." `Symbol`-keyed so the value can't collide with
/// other packages' zone values.
const Symbol _suppressKey = #otel_cloud_firestore_suppress;

/// Returns `true` when the current zone has opted out of Firestore
/// OTel instrumentation. The traced extension methods consult this
/// before opening a span.
bool firestoreInstrumentationSuppressed() {
  return Zone.current[_suppressKey] == true;
}

/// Runs [body] in a zone where the traced extension methods become
/// transparent passthroughs.
///
/// Preemptive defense: Firestore could plausibly be wired up as an
/// OTLP-over-Firestore sink (some teams use it as a cheap structured
/// log store). Mirrors the gRPC / HTTP / WebSocket suppression
/// helpers; safe to nest.
T runWithoutFirestoreInstrumentation<T>(T Function() body) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}

/// Async variant of [runWithoutFirestoreInstrumentation]. Both forms
/// are safe to nest; they no-op once already inside a suppressed
/// zone.
Future<T> runWithoutFirestoreInstrumentationAsync<T>(
  Future<T> Function() body,
) {
  return runZoned(body, zoneValues: {_suppressKey: true});
}
