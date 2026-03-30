import 'dart:math';
import '../models/expense_models.dart';

/// Utility class for expense calculation and validation logic
/// Handles equal, percentage, and exact split calculations with proper rounding and validation
class ExpenseCalculationUtils {
  
  /// Calculates equal splits for a given amount and number of participants
  /// Handles rounding differences by distributing extra cents to first participants
  static Map<String, double> calculateEqualSplits(
    double totalAmount,
    List<String> participantIds,
  ) {
    if (participantIds.isEmpty) {
      throw ArgumentError('Participant list cannot be empty');
    }
    
    if (totalAmount < 0) {
      throw ArgumentError('Total amount cannot be negative');
    }
    
    final Map<String, double> splits = {};
    final int participantCount = participantIds.length;
    
    // Convert to cents to avoid floating point issues
    final int totalCents = (totalAmount * 100).round();
    final int baseCentsPerPerson = totalCents ~/ participantCount;
    final int remainingCents = totalCents % participantCount;
    
    // Distribute the base amount and remaining cents
    for (int i = 0; i < participantCount; i++) {
      int centsForThisPerson = baseCentsPerPerson;
      
      // Add one extra cent to first few participants if there's a remainder
      if (i < remainingCents) {
        centsForThisPerson += 1;
      }
      
      splits[participantIds[i]] = centsForThisPerson / 100.0;
    }
    
    return splits;
  }
  
  /// Validates percentage splits to ensure they total exactly 100%
  /// Returns validation result with error message if invalid
  static SplitValidationResult validatePercentageSplits(
    Map<String, double> percentageSplits,
  ) {
    if (percentageSplits.isEmpty) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'No percentage splits provided',
      );
    }
    
    // Check for negative percentages
    for (final entry in percentageSplits.entries) {
      if (entry.value < 0) {
        return SplitValidationResult(
          isValid: false,
          errorMessage: 'Percentage for participant cannot be negative',
        );
      }
    }
    
    final double totalPercentage = percentageSplits.values.fold(0.0, (a, b) => a + b);
    
    // Allow small floating point tolerance (0.01%)
    if ((totalPercentage - 100.0).abs() > 0.01) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'Percentages must add up to 100% (currently ${totalPercentage.toStringAsFixed(1)}%)',
      );
    }
    
    return SplitValidationResult(isValid: true);
  }
  
  /// Validates exact amount splits to ensure they total the expense amount
  /// Returns validation result with error message if invalid
  static SplitValidationResult validateExactAmountSplits(
    Map<String, double> exactSplits,
    double totalAmount,
  ) {
    if (exactSplits.isEmpty) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'No exact amount splits provided',
      );
    }
    
    if (totalAmount < 0) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'Total amount cannot be negative',
      );
    }
    
    // Check for negative amounts
    for (final entry in exactSplits.entries) {
      if (entry.value < 0) {
        return SplitValidationResult(
          isValid: false,
          errorMessage: 'Split amount for participant cannot be negative',
        );
      }
    }
    
    final double totalSplit = exactSplits.values.fold(0.0, (a, b) => a + b);
    
    // Allow small floating point tolerance (0.01 currency units)
    if ((totalSplit - totalAmount).abs() > 0.01) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'Amounts must add up to ${formatCurrency(totalAmount)} (currently ${formatCurrency(totalSplit)})',
      );
    }
    
    return SplitValidationResult(isValid: true);
  }
  
  /// Calculates amounts from percentage splits
  /// Handles rounding differences by adjusting the largest split
  static Map<String, double> calculateAmountsFromPercentages(
    Map<String, double> percentageSplits,
    double totalAmount,
  ) {
    if (percentageSplits.isEmpty) {
      throw ArgumentError('Percentage splits cannot be empty');
    }
    
    if (totalAmount < 0) {
      throw ArgumentError('Total amount cannot be negative');
    }
    
    final Map<String, double> amounts = {};
    double calculatedTotal = 0.0;
    String? largestSplitKey;
    double largestSplitAmount = 0.0;
    
    // Calculate amounts for each participant
    for (final entry in percentageSplits.entries) {
      final double amount = _roundToCurrency((entry.value / 100.0) * totalAmount);
      amounts[entry.key] = amount;
      calculatedTotal += amount;
      
      // Track the largest split for rounding adjustment
      if (amount > largestSplitAmount) {
        largestSplitAmount = amount;
        largestSplitKey = entry.key;
      }
    }
    
    // Adjust for rounding differences by modifying the largest split
    final double difference = totalAmount - calculatedTotal;
    if (difference.abs() > 0.001 && largestSplitKey != null) {
      amounts[largestSplitKey!] = _roundToCurrency(amounts[largestSplitKey!]! + difference);
    }
    
    return amounts;
  }
  
  /// Validates split data based on split type
  /// Returns comprehensive validation result
  static SplitValidationResult validateSplitData(
    SplitType splitType,
    double totalAmount,
    List<String> participantIds,
    Map<String, double> customSplits,
  ) {
    if (participantIds.isEmpty) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'Please select at least one participant',
      );
    }
    
    if (totalAmount <= 0) {
      return SplitValidationResult(
        isValid: false,
        errorMessage: 'Total amount must be greater than zero',
      );
    }
    
    switch (splitType) {
      case SplitType.equal:
        // Equal splits don't need custom validation
        return SplitValidationResult(isValid: true);
        
      case SplitType.percentage:
        // Validate that all participants have percentage values
        for (final participantId in participantIds) {
          if (!customSplits.containsKey(participantId)) {
            return SplitValidationResult(
              isValid: false,
              errorMessage: 'Missing percentage for some participants',
            );
          }
        }
        return validatePercentageSplits(customSplits);
        
      case SplitType.exact:
        // Validate that all participants have exact amount values
        for (final participantId in participantIds) {
          if (!customSplits.containsKey(participantId)) {
            return SplitValidationResult(
              isValid: false,
              errorMessage: 'Missing amount for some participants',
            );
          }
        }
        return validateExactAmountSplits(customSplits, totalAmount);
    }
  }
  
  /// Calculates final split amounts based on split type
  /// Returns map of participant ID to their split amount
  static Map<String, double> calculateFinalSplits(
    SplitType splitType,
    double totalAmount,
    List<String> participantIds,
    Map<String, double> customSplits,
  ) {
    switch (splitType) {
      case SplitType.equal:
        return calculateEqualSplits(totalAmount, participantIds);
        
      case SplitType.percentage:
        return calculateAmountsFromPercentages(customSplits, totalAmount);
        
      case SplitType.exact:
        // For exact splits, return the custom splits as-is (already validated)
        return Map.from(customSplits);
    }
  }
  
  /// Formats currency amount to 2 decimal places
  static String formatCurrency(double amount, {String symbol = 'Rs. '}) {
    return '$symbol${amount.toStringAsFixed(2)}';
  }
  
  /// Rounds amount to 2 decimal places (currency precision)
  static double _roundToCurrency(double amount) {
    return (amount * 100).round() / 100;
  }
  
  /// Initializes custom splits for non-equal split types
  /// Used when user switches from equal to percentage/exact splits
  static Map<String, double> initializeCustomSplits(
    SplitType splitType,
    double totalAmount,
    List<String> participantIds,
  ) {
    if (participantIds.isEmpty) {
      return {};
    }
    
    final Map<String, double> customSplits = {};
    final int count = participantIds.length;
    
    switch (splitType) {
      case SplitType.equal:
        // Equal splits don't need custom values
        break;
        
      case SplitType.percentage:
        final double equalPercentage = 100.0 / count;
        for (final id in participantIds) {
          customSplits[id] = _roundToCurrency(equalPercentage);
        }
        break;
        
      case SplitType.exact:
        final double equalAmount = totalAmount / count;
        for (final id in participantIds) {
          customSplits[id] = _roundToCurrency(equalAmount);
        }
        break;
    }
    
    return customSplits;
  }
}

/// Result class for split validation operations
class SplitValidationResult {
  final bool isValid;
  final String? errorMessage;
  
  SplitValidationResult({
    required this.isValid,
    this.errorMessage,
  });
  
  @override
  String toString() {
    return 'SplitValidationResult(isValid: $isValid, errorMessage: $errorMessage)';
  }
}