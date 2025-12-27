import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/models/expense_models.dart';

void main() {
  group('MobileDashboard Recent Expenses', () {
    test('ExpenseData.fromJson should parse API response correctly', () {
      final json = {
        'id': 1,
        'title': 'Test Expense',
        'amount': 100.50,
        'description': 'Test description',
        'category': 'Food',
        'paid_by': 'user123',
        'payer_name': 'John Doe',
        'split_type': 'EQUAL',
        'created_at': '2023-10-25T10:30:00Z',
        'splits': [
          {
            'user_uid': 'user123',
            'user_name': 'John Doe',
            'amount': 50.25,
          },
          {
            'user_uid': 'user456',
            'user_name': 'Jane Smith',
            'amount': 50.25,
          }
        ]
      };

      final expense = ExpenseData.fromJson(json);

      expect(expense.id, equals(1));
      expect(expense.title, equals('Test Expense'));
      expect(expense.amount, equals(100.50));
      expect(expense.description, equals('Test description'));
      expect(expense.category, equals('Food'));
      expect(expense.paidBy, equals('user123'));
      expect(expense.payerName, equals('John Doe'));
      expect(expense.splitType, equals(SplitType.equal));
      expect(expense.createdAt, isNotNull);
      expect(expense.splits, hasLength(2));
      expect(expense.splits![0].userName, equals('John Doe'));
      expect(expense.splits![0].amount, equals(50.25));
    });

    test('ExpenseData.fromJson should handle missing optional fields', () {
      final json = {
        'title': 'Minimal Expense',
        'amount': 50.0,
        'description': '',
        'category': 'Other',
      };

      final expense = ExpenseData.fromJson(json);

      expect(expense.title, equals('Minimal Expense'));
      expect(expense.amount, equals(50.0));
      expect(expense.id, isNull);
      expect(expense.paidBy, isNull);
      expect(expense.payerName, isNull);
      expect(expense.createdAt, isNull);
      expect(expense.splits, isNull);
      expect(expense.splitType, equals(SplitType.equal)); // Default value
    });

    test('ExpenseData.fromJson should handle different split types', () {
      final jsonPercentage = {
        'title': 'Percentage Split',
        'amount': 100.0,
        'description': 'Test',
        'category': 'Food',
        'split_type': 'PERCENTAGE',
      };

      final jsonExact = {
        'title': 'Exact Split',
        'amount': 100.0,
        'description': 'Test',
        'category': 'Food',
        'split_type': 'EXACT',
      };

      final expensePercentage = ExpenseData.fromJson(jsonPercentage);
      final expenseExact = ExpenseData.fromJson(jsonExact);

      expect(expensePercentage.splitType, equals(SplitType.percentage));
      expect(expenseExact.splitType, equals(SplitType.exact));
    });

    test('ExpenseSplit.fromJson should parse split data correctly', () {
      final json = {
        'user_uid': 'user123',
        'user_name': 'John Doe',
        'amount': 25.50,
        'percentage': 50.0,
      };

      final split = ExpenseSplit.fromJson(json);

      expect(split.userUid, equals('user123'));
      expect(split.userName, equals('John Doe'));
      expect(split.amount, equals(25.50));
      expect(split.percentage, equals(50.0));
    });

    test('ExpenseCreateRequest.fromExpenseData should create correct request', () {
      final expenseData = ExpenseData(
        title: 'Test Expense',
        amount: 100.0,
        description: 'Test description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.equal,
        customSplits: {},
      );

      final request = ExpenseCreateRequest.fromExpenseData(expenseData, "123");

      expect(request.roomspaceId, equals("123"));
      expect(request.title, equals('Test Expense'));
      expect(request.amount, equals(100.0));
      expect(request.description, equals('Test description'));
      expect(request.category, equals('Food'));
      expect(request.splitType, equals('EQUAL'));
      expect(request.selectedRoommates, equals(['user1', 'user2']));
      expect(request.customSplits, isNull);
    });
  });
}