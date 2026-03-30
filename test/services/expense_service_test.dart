import 'package:flutter_test/flutter_test.dart';
import 'package:room_ease/models/expense_models.dart';
import 'package:room_ease/services/expense_service.dart';

void main() {
  group('ExpenseService', () {
    test('should create ExpenseCreateRequest from ExpenseData', () {
      // Arrange
      final expenseData = ExpenseData(
        title: 'Test Expense',
        amount: 100.0,
        description: 'Test description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.equal,
        customSplits: {},
      );

      // Act
      final request = ExpenseCreateRequest.fromExpenseData(expenseData, "1");

      // Assert
      expect(request.roomspaceId, equals("1"));
      expect(request.title, equals('Test Expense'));
      expect(request.amount, equals(100.0));
      expect(request.description, equals('Test description'));
      expect(request.category, equals('Food'));
      expect(request.splitType, equals('EQUAL'));
      expect(request.selectedRoommates, equals(['user1', 'user2']));
      expect(request.customSplits, isNull);
    });

    test('should create ExpenseCreateRequest with custom splits', () {
      // Arrange
      final expenseData = ExpenseData(
        title: 'Test Expense',
        amount: 100.0,
        description: 'Test description',
        category: 'Food',
        selectedRoommateIds: ['user1', 'user2'],
        splitType: SplitType.percentage,
        customSplits: {'user1': 60.0, 'user2': 40.0},
      );

      // Act
      final request = ExpenseCreateRequest.fromExpenseData(expenseData, "1");

      // Assert
      expect(request.customSplits, isNotNull);
      expect(request.customSplits!['user1'], equals(60.0));
      expect(request.customSplits!['user2'], equals(40.0));
      expect(request.splitType, equals('PERCENTAGE'));
    });

    test('should parse ExpenseData from JSON response', () {
      // Arrange
      final json = {
        'id': 1,
        'title': 'Test Expense',
        'amount': 100.0,
        'description': 'Test description',
        'category': 'Food',
        'paid_by': 'user123',
        'payer_name': 'John Doe',
        'split_type': 'EQUAL',
        'created_at': '2023-12-01T10:00:00Z',
        'splits': [
          {
            'user_uid': 'user1',
            'user_name': 'Alice',
            'amount': 50.0,
          },
          {
            'user_uid': 'user2',
            'user_name': 'Bob',
            'amount': 50.0,
          },
        ],
      };

      // Act
      final expenseData = ExpenseData.fromJson(json);

      // Assert
      expect(expenseData.id, equals(1));
      expect(expenseData.title, equals('Test Expense'));
      expect(expenseData.amount, equals(100.0));
      expect(expenseData.description, equals('Test description'));
      expect(expenseData.category, equals('Food'));
      expect(expenseData.paidBy, equals('user123'));
      expect(expenseData.payerName, equals('John Doe'));
      expect(expenseData.splitType, equals(SplitType.equal));
      expect(expenseData.createdAt, isNotNull);
      expect(expenseData.splits, hasLength(2));
      expect(expenseData.splits![0].userUid, equals('user1'));
      expect(expenseData.splits![0].userName, equals('Alice'));
      expect(expenseData.splits![0].amount, equals(50.0));
    });

    test('should handle SplitType enum conversion', () {
      expect(SplitType.fromString('EQUAL'), equals(SplitType.equal));
      expect(SplitType.fromString('PERCENTAGE'), equals(SplitType.percentage));
      expect(SplitType.fromString('EXACT'), equals(SplitType.exact));
      expect(SplitType.fromString('invalid'), equals(SplitType.equal)); // default
      
      expect(SplitType.equal.apiValue, equals('EQUAL'));
      expect(SplitType.percentage.apiValue, equals('PERCENTAGE'));
      expect(SplitType.exact.apiValue, equals('EXACT'));
    });

    test('should create ExpenseListResponse with correct metadata', () {
      // Arrange
      final expenses = [
        ExpenseData(
          title: 'Expense 1',
          amount: 50.0,
          description: '',
          category: 'Food',
          selectedRoommateIds: [],
          splitType: SplitType.equal,
          customSplits: {},
        ),
      ];

      // Act
      final response = ExpenseListResponse(
        expenses: expenses,
        limit: 20,
        offset: 0,
        count: 1,
      );

      // Assert
      expect(response.expenses, hasLength(1));
      expect(response.limit, equals(20));
      expect(response.offset, equals(0));
      expect(response.count, equals(1));
      expect(response.hasMore, isFalse); // count < limit
      expect(response.nextOffset, equals(1)); // offset + count
    });

    test('should indicate hasMore when count equals limit', () {
      // Arrange
      final expenses = List.generate(20, (index) => ExpenseData(
        title: 'Expense $index',
        amount: 50.0,
        description: '',
        category: 'Food',
        selectedRoommateIds: [],
        splitType: SplitType.equal,
        customSplits: {},
      ));

      // Act
      final response = ExpenseListResponse(
        expenses: expenses,
        limit: 20,
        offset: 0,
        count: 20,
      );

      // Assert
      expect(response.hasMore, isTrue); // count == limit
      expect(response.nextOffset, equals(20)); // offset + count
    });
  });
}