// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/utils/expense_calculation_utils.dart';

void main() {
  testWidgets('ExpenseCalculationUtils integration test', (WidgetTester tester) async {
    // Test that the calculation utilities work correctly
    final result = ExpenseCalculationUtils.calculateEqualSplits(
      100.0,
      ['user1', 'user2', 'user3', 'user4'],
    );
    
    expect(result.length, equals(4));
    expect(result['user1'], equals(25.0));
    expect(result['user2'], equals(25.0));
    expect(result['user3'], equals(25.0));
    expect(result['user4'], equals(25.0));
  });
}
