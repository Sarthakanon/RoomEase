import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/models/expense_models.dart';

void main() {
  group('ExpenseCreateRequest', () {
    test('should convert from ExpenseData correctly', () {
      // Arrange
      final expenseData = ExpenseData(
        title: 'Test Expense',
        amount: 100.50,
        description: 'Test Description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.equal,
        customSplits: {},
      );

      // Act
      final request = ExpenseCreateRequest.fromExpenseData(expenseData, "123");

      // Assert
      expect(request.roomspaceId, equals("123"));
      expect(request.title, equals('Test Expense'));
      expect(request.amount, equals(100.50));
      expect(request.description, equals('Test Description'));
      expect(request.category, equals('Food'));
      expect(request.splitType, equals('EQUAL'));
      expect(request.selectedRoommates, equals(['user1', 'user2']));
      expect(request.customSplits, isNull);
    });

    test('should include custom splits when provided', () {
      // Arrange
      final expenseData = ExpenseData(
        title: 'Test Expense',
        amount: 100.00,
        description: 'Test Description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.exact,
        customSplits: {'user1': 60.0, 'user2': 40.0},
      );

      // Act
      final request = ExpenseCreateRequest.fromExpenseData(expenseData, "123");

      // Assert
      expect(request.splitType, equals('EXACT'));
      expect(request.customSplits, isNotNull);
      expect(request.customSplits!['user1'], equals(60.0));
      expect(request.customSplits!['user2'], equals(40.0));
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final request = ExpenseCreateRequest(
        roomspaceId: 123,
        title: 'Test Expense',
        description: 'Test Description',
        amount: 100.50,
        category: 'Food',
        splitType: 'EQUAL',
        selectedRoommates: ['user1', 'user2'],
      );

      // Act
      final json = request.toJson();

      // Assert
      expect(json['roomspace_id'], equals(123));
      expect(json['title'], equals('Test Expense'));
      expect(json['description'], equals('Test Description'));
      expect(json['amount'], equals(100.50));
      expect(json['category'], equals('Food'));
      expect(json['split_type'], equals('EQUAL'));
      expect(json['selected_roommates'], equals(['user1', 'user2']));
      expect(json.containsKey('custom_splits'), isFalse);
    });

    test('should include custom splits in JSON when provided', () {
      // Arrange
      final request = ExpenseCreateRequest(
        roomspaceId: 123,
        title: 'Test Expense',
        description: 'Test Description',
        amount: 100.00,
        category: 'Food',
        splitType: 'EXACT',
        selectedRoommates: ['user1', 'user2'],
        customSplits: {'user1': 60.0, 'user2': 40.0},
      );

      // Act
      final json = request.toJson();

      // Assert
      expect(json['custom_splits'], isNotNull);
      expect(json['custom_splits']['user1'], equals(60.0));
      expect(json['custom_splits']['user2'], equals(40.0));
    });
  });

  group('ExpenseData', () {
    test('should create from JSON correctly', () {
      // Arrange
      final json = {
        'id': 1,
        'title': 'Test Expense',
        'amount': 100.50,
        'description': 'Test Description',
        'category': 'Food',
        'split_type': 'EQUAL',
        'roomspace_id': 123,
        'paid_by': 'user123',
        'payer_name': 'John Doe',
        'created_at': '2023-12-21T10:00:00Z',
        'splits': [
          {
            'user_uid': 'user1',
            'user_name': 'User One',
            'amount': 50.25,
          },
          {
            'user_uid': 'user2',
            'user_name': 'User Two',
            'amount': 50.25,
          }
        ]
      };

      // Act
      final expense = ExpenseData.fromJson(json);

      // Assert
      expect(expense.id, equals(1));
      expect(expense.title, equals('Test Expense'));
      expect(expense.amount, equals(100.50));
      expect(expense.description, equals('Test Description'));
      expect(expense.category, equals('Food'));
      expect(expense.splitType, equals(SplitType.equal));
      expect(expense.roomspaceId, equals(123));
      expect(expense.paidBy, equals('user123'));
      expect(expense.payerName, equals('John Doe'));
      expect(expense.createdAt, isNotNull);
      expect(expense.splits, hasLength(2));
      expect(expense.splits![0].userUid, equals('user1'));
      expect(expense.splits![0].userName, equals('User One'));
      expect(expense.splits![0].amount, equals(50.25));
    });

    test('should convert to JSON correctly', () {
      // Arrange
      final expense = ExpenseData(
        title: 'Test Expense',
        amount: 100.50,
        description: 'Test Description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.percentage,
        customSplits: {'user1': 60.0, 'user2': 40.0},
      );

      // Act
      final json = expense.toJson();

      // Assert
      expect(json['title'], equals('Test Expense'));
      expect(json['amount'], equals(100.50));
      expect(json['description'], equals('Test Description'));
      expect(json['category'], equals('Food'));
      expect(json['split_type'], equals('PERCENTAGE'));
      expect(json['selected_roommates'], equals(['user1', 'user2']));
      expect(json['custom_splits'], equals({'user1': 60.0, 'user2': 40.0}));
    });
  });

  group('SplitType', () {
    test('should convert from string correctly', () {
      expect(SplitType.fromString('EQUAL'), equals(SplitType.equal));
      expect(SplitType.fromString('PERCENTAGE'), equals(SplitType.percentage));
      expect(SplitType.fromString('EXACT'), equals(SplitType.exact));
      expect(SplitType.fromString('equal'), equals(SplitType.equal));
      expect(SplitType.fromString('invalid'), equals(SplitType.equal)); // Default
    });

    test('should have correct API values', () {
      expect(SplitType.equal.apiValue, equals('EQUAL'));
      expect(SplitType.percentage.apiValue, equals('PERCENTAGE'));
      expect(SplitType.exact.apiValue, equals('EXACT'));
    });
  });
}