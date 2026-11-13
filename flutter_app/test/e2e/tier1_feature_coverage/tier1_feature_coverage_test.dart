import 'package:flutter_test/flutter_test.dart';

import 'test_r1_startup_coverage_test.dart' as r1;
import 'test_r2_atomic_persistence_test.dart' as r2;
import 'test_r3_date_validation_test.dart' as r3;
import 'test_r4_unlock_sync_test.dart' as r4;
import 'test_r5_debouncing_test.dart' as r5;
import 'test_r6_security_rules_test.dart' as r6;
import 'test_r7_session_parsing_test.dart' as r7;

/// Aggregator test suite that runs all 35 Tier 1 Feature Coverage tests
/// across Requirements R1 through R7.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 1 Complete Feature Coverage Suite (R1-R7)', () {
    group('R1: Startup Resilience & Crash Prevention', r1.main);
    group('R2: Atomic Persistence and Lot Rescheduling', r2.main);
    group('R3: Date Range Validation in Session Registration', r3.main);
    group('R4: 120-Day Unlock Cycle Synchronization', r4.main);
    group('R5: Mutation Idempotency & UI Debouncing', r5.main);
    group('R6: Firestore Security Rules & Immutability', r6.main);
    group('R7: Resilient SharedPreferences Session Parsing', r7.main);
  });
}
