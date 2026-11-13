import 'package:flutter_test/flutter_test.dart';

import 'test_r1_startup_boundaries_test.dart' as r1;
import 'test_r2_persistence_bounds_test.dart' as r2;
import 'test_r3_date_boundaries_test.dart' as r3;
import 'test_r4_unlock_boundaries_test.dart' as r4;
import 'test_r5_debounce_stress_test.dart' as r5;
import 'test_r6_security_attacks_test.dart' as r6;
import 'test_r7_corruption_bounds_test.dart' as r7;

/// Aggregator test suite that runs all 35 Tier 2 Boundary & Corner Case tests
/// across Requirements R1 through R7.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Tier 2 Complete Boundary & Corner Cases Suite (R1-R7)', () {
    group('R1: Startup Boundaries & Cold Start Limits', r1.main);
    group('R2: Persistence Boundaries & Atomic Fault Tolerance', r2.main);
    group('R3: Date Range Boundaries & UI Form Validation', r3.main);
    group('R4: Unlock Boundaries & Calendar Traversal', r4.main);
    group('R5: Debounce Stress & Mutex Concurrency', r5.main);
    group('R6: Security Attack Scenarios & CEL Rules Enforcement', r6.main);
    group('R7: Corruption Bounds & Session Recovery Resilience', r7.main);
  });
}
