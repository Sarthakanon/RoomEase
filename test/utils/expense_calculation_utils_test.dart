import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/utils/expense_calculation_utils.dart';
import 'package:room_ease/models/expense_models.dart';

void main() {
  group('ExpenseCalculationUtils', () {
    group('calculateEqualSplits', () {
      test('should divide amount equally among participants', () {
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
      
      test('should handle rounding differences by distributing extra cents', () {
        final result = ExpenseCalculationUtils.calculateEqualSplits(
          100.01,
          ['user1', 'user2', 'user3'],
        );
        
        expect(result.length, equals(3));
        
        // Verify total is preserved
        final total = result.values.fold(0.0, (a, b) => a + b);
        expect(total, closeTo(100.01, 0.001));
        
        // Check that all values are reasonable (around 33.33-33.34)
        for (final value in result.values) {
          expect(value, greaterThanOrEqualTo(33.33));
          expect(value, lessThanOrEqualTo(33.34));
        }
      });
      
      test('should handle single participant', () {
        final result = ExpenseCalculationUtils.calculateEqualSplits(
          50.75,
          ['user1'],
        );
        
        expect(result.length, equals(1));
        expect(result['user1'], equals(50.75));
      });
      
      test('should handle zero amount', () {
        final result = ExpenseCalculationUtils.calculateEqualSplits(
          0.0,
          ['user1', 'user2'],
        );
        
        expect(result.length, equals(2));
        expect(result['user1'], equals(0.0));
        expect(result['user2'], equals(0.0));
      });
      
      test('should throw error for empty participant list', () {
        expect(
          () => ExpenseCalculationUtils.calculateEqualSplits(100.0, []),
          throwsArgumentError,
        );
      });
      
      test('should throw error for negative amount', () {
        expect(
          () => ExpenseCalculationUtils.calculateEqualSplits(-10.0, ['user1']),
          throwsArgumentError,
        );
      });
    });
    
    group('validatePercentageSplits', () {
      test('should validate correct percentage splits', () {
        final result = ExpenseCalculationUtils.validatePercentageSplits({
          'user1': 60.0,
          'user2': 40.0,
        });
        
        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });
      
      test('should allow small floating point tolerance', () {
        final result = ExpenseCalculationUtils.validatePercentageSplits({
          'user1': 33.33,
          'user2': 33.33,
          'user3': 33.34,
        });
        
        expect(result.isValid, isTrue);
      });
      
      test('should reject percentages that do not total 100%', () {
        final result = ExpenseCalculationUtils.validatePercentageSplits({
          'user1': 60.0,
          'user2': 30.0,
        });
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('must add up to 100%'));
        expect(result.errorMessage, contains('90.0%'));
      });
      
      test('should reject negative percentages', () {
        final result = ExpenseCalculationUtils.validatePercentageSplits({
          'user1': -10.0,
          'user2': 110.0,
        });
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('cannot be negative'));
      });
      
      test('should reject empty splits', () {
        final result = ExpenseCalculationUtils.validatePercentageSplits({});
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('No percentage splits provided'));
      });
    });
    
    group('validateExactAmountSplits', () {
      test('should validate correct exact amount splits', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({
          'user1': 60.0,
          'user2': 40.0,
        }, 100.0);
        
        expect(result.isValid, isTrue);
        expect(result.errorMessage, isNull);
      });
      
      test('should allow small floating point tolerance', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({
          'user1': 33.33,
          'user2': 33.33,
          'user3': 33.34,
        }, 100.0);
        
        expect(result.isValid, isTrue);
      });
      
      test('should reject amounts that do not total expense amount', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({
          'user1': 60.0,
          'user2': 30.0,
        }, 100.0);
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('must add up to'));
        expect(result.errorMessage, contains('Rs. 100.00'));
        expect(result.errorMessage, contains('Rs. 90.00'));
      });
      
      test('should reject negative amounts', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({
          'user1': -10.0,
          'user2': 110.0,
        }, 100.0);
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('cannot be negative'));
      });
      
      test('should reject empty splits', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({}, 100.0);
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('No exact amount splits provided'));
      });
      
      test('should reject negative total amount', () {
        final result = ExpenseCalculationUtils.validateExactAmountSplits({
          'user1': 50.0,
        }, -100.0);
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Total amount cannot be negative'));
      });
    });
    
    group('calculateAmountsFromPercentages', () {
      test('should calculate amounts from percentages correctly', () {
        final result = ExpenseCalculationUtils.calculateAmountsFromPercentages({
          'user1': 60.0,
          'user2': 40.0,
        }, 100.0);
        
        expect(result['user1'], equals(60.0));
        expect(result['user2'], equals(40.0));
      });
      
      test('should handle rounding by adjusting largest split', () {
        final result = ExpenseCalculationUtils.calculateAmountsFromPercentages({
          'user1': 33.33,
          'user2': 33.33,
          'user3': 33.34,
        }, 100.0);
        
        // Verify total is preserved
        final total = result.values.fold(0.0, (a, b) => a + b);
        expect(total, closeTo(100.0, 0.001));
        
        // All amounts should be reasonable
        expect(result['user1'], closeTo(33.33, 0.1));
        expect(result['user2'], closeTo(33.33, 0.1));
        expect(result['user3'], closeTo(33.34, 0.1));
      });
      
      test('should throw error for empty percentages', () {
        expect(
          () => ExpenseCalculationUtils.calculateAmountsFromPercentages({}, 100.0),
          throwsArgumentError,
        );
      });
      
      test('should throw error for negative total amount', () {
        expect(
          () => ExpenseCalculationUtils.calculateAmountsFromPercentages({
            'user1': 100.0,
          }, -50.0),
          throwsArgumentError,
        );
      });
    });
    
    group('validateSplitData', () {
      test('should validate equal splits without custom data', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.equal,
          100.0,
          ['user1', 'user2'],
          {},
        );
        
        expect(result.isValid, isTrue);
      });
      
      test('should validate percentage splits with custom data', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.percentage,
          100.0,
          ['user1', 'user2'],
          {'user1': 60.0, 'user2': 40.0},
        );
        
        expect(result.isValid, isTrue);
      });
      
      test('should validate exact splits with custom data', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.exact,
          100.0,
          ['user1', 'user2'],
          {'user1': 60.0, 'user2': 40.0},
        );
        
        expect(result.isValid, isTrue);
      });
      
      test('should reject empty participant list', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.equal,
          100.0,
          [],
          {},
        );
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('select at least one participant'));
      });
      
      test('should reject zero or negative total amount', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.equal,
          0.0,
          ['user1'],
          {},
        );
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('must be greater than zero'));
      });
      
      test('should reject percentage splits missing participant data', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.percentage,
          100.0,
          ['user1', 'user2'],
          {'user1': 60.0}, // Missing user2
        );
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Missing percentage'));
      });
      
      test('should reject exact splits missing participant data', () {
        final result = ExpenseCalculationUtils.validateSplitData(
          SplitType.exact,
          100.0,
          ['user1', 'user2'],
          {'user1': 60.0}, // Missing user2
        );
        
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('Missing amount'));
      });
    });
    
    group('calculateFinalSplits', () {
      test('should calculate equal splits', () {
        final result = ExpenseCalculationUtils.calculateFinalSplits(
          SplitType.equal,
          100.0,
          ['user1', 'user2'],
          {},
        );
        
        expect(result['user1'], equals(50.0));
        expect(result['user2'], equals(50.0));
      });
      
      test('should calculate percentage-based splits', () {
        final result = ExpenseCalculationUtils.calculateFinalSplits(
          SplitType.percentage,
          100.0,
          ['user1', 'user2'],
          {'user1': 60.0, 'user2': 40.0},
        );
        
        expect(result['user1'], equals(60.0));
        expect(result['user2'], equals(40.0));
      });
      
      test('should return exact splits as-is', () {
        final customSplits = {'user1': 60.0, 'user2': 40.0};
        final result = ExpenseCalculationUtils.calculateFinalSplits(
          SplitType.exact,
          100.0,
          ['user1', 'user2'],
          customSplits,
        );
        
        expect(result, equals(customSplits));
      });
    });
    
    group('formatCurrency', () {
      test('should format currency with default symbol', () {
        expect(ExpenseCalculationUtils.formatCurrency(123.45), equals('Rs. 123.45'));
      });
      
      test('should format currency with custom symbol', () {
        expect(
          ExpenseCalculationUtils.formatCurrency(123.45, symbol: '\$'),
          equals('\$123.45'),
        );
      });
      
      test('should format currency with proper decimal places', () {
        expect(ExpenseCalculationUtils.formatCurrency(123.4), equals('Rs. 123.40'));
        expect(ExpenseCalculationUtils.formatCurrency(123), equals('Rs. 123.00'));
      });
    });
    
    group('initializeCustomSplits', () {
      test('should initialize equal percentage splits', () {
        final result = ExpenseCalculationUtils.initializeCustomSplits(
          SplitType.percentage,
          100.0,
          ['user1', 'user2', 'user3'],
        );
        
        expect(result.length, equals(3));
        expect(result['user1'], closeTo(33.33, 0.01));
        expect(result['user2'], closeTo(33.33, 0.01));
        expect(result['user3'], closeTo(33.33, 0.01));
      });
      
      test('should initialize equal amount splits', () {
        final result = ExpenseCalculationUtils.initializeCustomSplits(
          SplitType.exact,
          100.0,
          ['user1', 'user2'],
        );
        
        expect(result.length, equals(2));
        expect(result['user1'], equals(50.0));
        expect(result['user2'], equals(50.0));
      });
      
      test('should return empty map for equal split type', () {
        final result = ExpenseCalculationUtils.initializeCustomSplits(
          SplitType.equal,
          100.0,
          ['user1', 'user2'],
        );
        
        expect(result, isEmpty);
      });
      
      test('should return empty map for empty participant list', () {
        final result = ExpenseCalculationUtils.initializeCustomSplits(
          SplitType.percentage,
          100.0,
          [],
        );
        
        expect(result, isEmpty);
      });
    });
  });
  
  group('SplitValidationResult', () {
    test('should create valid result', () {
      final result = SplitValidationResult(isValid: true);
      
      expect(result.isValid, isTrue);
      expect(result.errorMessage, isNull);
    });
    
    test('should create invalid result with message', () {
      final result = SplitValidationResult(
        isValid: false,
        errorMessage: 'Test error',
      );
      
      expect(result.isValid, isFalse);
      expect(result.errorMessage, equals('Test error'));
    });
    
    test('should have proper toString representation', () {
      final result = SplitValidationResult(
        isValid: false,
        errorMessage: 'Test error',
      );
      
      expect(result.toString(), contains('isValid: false'));
      expect(result.toString(), contains('errorMessage: Test error'));
    });
  });
}