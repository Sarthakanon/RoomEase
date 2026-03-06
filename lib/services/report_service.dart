import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../models/expense_models.dart';
import '../models/balance_models.dart';
import 'package:intl/intl.dart';
import 'package:flutter/material.dart' show DateTimeRange;

class ReportService {
  static final ReportService _instance = ReportService._internal();
  factory ReportService() => _instance;
  ReportService._internal();

  Future<Uint8List> generateExpenseReport({
    required List<ExpenseData> sharedExpenses,
    required List<PersonalExpenseData> personalExpenses,
    required DateTimeRange dateRange,
    required String roomspaceName,
    required String userName,
    BalanceSummary? balanceSummary,
    List<SettlementSuggestion> settlements = const [],
  }) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('MMM dd, yyyy');
    
    final totalShared = sharedExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final totalPersonal = personalExpenses.fold(0.0, (sum, item) => sum + item.amount);
    final totalSpending = totalShared + totalPersonal;

    final font = await PdfGoogleFonts.interRegular();
    final boldFont = await PdfGoogleFonts.interBold();

    final insights = _generateAiInsights(sharedExpenses, personalExpenses, dateRange);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        theme: pw.ThemeData.withFont(base: font, bold: boldFont),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('Financial Activity Report', style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                    pw.Text(roomspaceName, style: pw.TextStyle(fontSize: 14, color: PdfColors.indigo, fontWeight: pw.FontWeight.bold)),
                    pw.Text('Period: ${dateFormat.format(dateRange.start)} - ${dateFormat.format(dateRange.end)}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text('Generated: ${dateFormat.format(DateTime.now())}', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                    pw.Text('Account: $userName', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.indigo100, thickness: 2),
            pw.SizedBox(height: 15),

            // Performance Dashboard
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                _buildStatCard('Shared Spending', totalShared, PdfColors.indigo700),
                _buildStatCard('Personal Spending', totalPersonal, PdfColors.orange700),
                _buildStatCard('Total Volume', totalSpending, PdfColors.blueGrey900),
              ],
            ),
            pw.SizedBox(height: 30),

            // AI Insights Section
            pw.Container(
              padding: const pw.EdgeInsets.all(15),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey50,
                borderRadius: pw.BorderRadius.circular(10),
                border: pw.Border.all(color: PdfColors.indigo50),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    children: [
                      pw.Text('Smart Financial Insights', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                      pw.SizedBox(width: 5),
                      pw.Container(width: 30, height: 1, color: PdfColors.indigo100),
                    ],
                  ),
                  pw.SizedBox(height: 10),
                  ...insights.map((insight) => pw.Padding(
                    padding: const pw.EdgeInsets.only(bottom: 6),
                    child: pw.Row(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text('• ', style: pw.TextStyle(color: PdfColors.indigo, fontWeight: pw.FontWeight.bold)),
                        pw.Expanded(child: pw.Text(insight, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey800))),
                      ],
                    ),
                  )).toList(),
                ],
              ),
            ),
            pw.SizedBox(height: 30),

            // Settlement & Balances
            if (balanceSummary != null) ...[
              pw.Text('Outstanding Balances', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
              pw.SizedBox(height: 10),
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
                cellHeight: 25,
                cellAlignment: pw.Alignment.centerLeft,
                headers: ['Roommate', 'Status', 'Balance'],
                data: balanceSummary.members.map((m) {
                  final bal = (m['balance'] as num).toDouble();
                  return [
                    m['name'],
                    bal > 0 ? 'Owed' : bal < 0 ? 'Owes' : 'Settled',
                    'Rs. ${bal.abs().toStringAsFixed(2)}',
                  ];
                }).toList(),
              ),
              pw.SizedBox(height: 20),
            ],

            if (settlements.isNotEmpty) ...[
              pw.Text('Recommended Settlements', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...settlements.map((s) => pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 4),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: const pw.BoxDecoration(color: PdfColors.green50, border: pw.Border(left: pw.BorderSide(color: PdfColors.green, width: 3))),
                  child: pw.Text('${s.fromUserName} should pay Rs. ${s.amount.toStringAsFixed(2)} to ${s.toUserName}', style: const pw.TextStyle(fontSize: 10)),
                ),
              )).toList(),
              pw.SizedBox(height: 30),
            ],

            // Detailed Expense Logs
            pw.Text('Itemized Shared Expenses', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo)),
            pw.SizedBox(height: 10),
            if (sharedExpenses.isEmpty) 
               pw.Text('No shared expenses recorded for this period.', style: pw.TextStyle(color: PdfColors.grey500, fontStyle: pw.FontStyle.italic, fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Date', 'Title', 'Category', 'Paid By', 'Amount'],
                data: sharedExpenses.map((e) => [
                  dateFormat.format(e.createdAt ?? DateTime.now()),
                  e.title,
                  e.category,
                  e.payerName ?? 'User',
                  'Rs. ${e.amount.toStringAsFixed(0)}',
                ]).toList(),
              ),
            pw.SizedBox(height: 30),

            pw.Text('Itemized Personal Expenses', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.orange)),
            pw.SizedBox(height: 10),
            if (personalExpenses.isEmpty) 
               pw.Text('No personal expenses recorded for this period.', style: pw.TextStyle(color: PdfColors.grey500, fontStyle: pw.FontStyle.italic, fontSize: 10))
            else
              pw.TableHelper.fromTextArray(
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.orange),
                cellStyle: const pw.TextStyle(fontSize: 9),
                headers: ['Date', 'Title', 'Category', 'Amount'],
                data: personalExpenses.map((e) => [
                  dateFormat.format(e.createdAt ?? DateTime.now()),
                  e.title,
                  e.category,
                  'Rs. ${e.amount.toStringAsFixed(0)}',
                ]).toList(),
              ),
            pw.SizedBox(height: 40),

            // FINAL SETTLEMENT SUMMARY - AT THE END
            pw.Container(
              padding: const pw.EdgeInsets.all(20),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(12),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text('FINAL SETTLEMENT SUMMARY', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900)),
                  pw.SizedBox(height: 5),
                  pw.Text('The following actions are required to balance all accounts for this period:', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
                  pw.SizedBox(height: 15),

                  if (settlements.isEmpty)
                    pw.Center(
                      child: pw.Text('ALL ACCOUNTS ARE SETTLED. NO PAYMENTS REQUIRED.', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.green700, fontSize: 11)),
                    )
                  else
                    ...settlements.map((s) => pw.Padding(
                      padding: const pw.EdgeInsets.only(bottom: 10),
                      child: pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Row(
                            children: [
                              pw.Container(
                                width: 8, height: 8, 
                                decoration: const pw.BoxDecoration(color: PdfColors.orange, shape: pw.BoxShape.circle)
                              ),
                              pw.SizedBox(width: 8),
                              pw.Text(s.fromUserName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                              pw.SizedBox(width: 5),
                              pw.Text('needs to pay', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey800)),
                              pw.SizedBox(width: 5),
                              pw.Text(s.toUserName, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 11)),
                            ],
                          ),
                          pw.Text('Rs. ${s.amount.toStringAsFixed(2)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 13, color: PdfColors.indigo700)),
                        ],
                      ),
                    )).toList(),
                  
                  pw.SizedBox(height: 15),
                  pw.Divider(color: PdfColors.grey400, thickness: 0.5),
                  pw.SizedBox(height: 10),
                  
                  if (balanceSummary != null)
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text('Individual Status Breakdown:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                        pw.Row(
                          children: balanceSummary.members.map((m) {
                            final bal = (m['balance'] as num).toDouble();
                            return pw.Padding(
                              padding: const pw.EdgeInsets.only(left: 15),
                              child: pw.Text('${m['name']}: ${bal >= 0 ? "+" : ""}${bal.toStringAsFixed(0)}', style: pw.TextStyle(fontSize: 9, color: bal >= 0 ? PdfColors.green700 : PdfColors.red700)),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                ],
              ),
            ),

            // Footer
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColors.grey200),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('© RoomEase Expense Management System', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
                pw.Text('Official Financial Record', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  pw.Widget _buildStatCard(String label, double amount, PdfColor color) {
    return pw.Container(
      width: 160,
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: PdfColors.white,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: PdfColors.grey200),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(label, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
          pw.SizedBox(height: 5),
          pw.Text('Rs. ${amount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  List<String> _generateAiInsights(List<ExpenseData> shared, List<PersonalExpenseData> personal, DateTimeRange range) {
    final insights = <String>[];
    
    final totalShared = shared.fold(0.0, (sum, e) => sum + e.amount);
    final totalPersonal = personal.fold(0.0, (sum, e) => sum + e.amount);
    
    // Total Spending Insight
    if (totalShared + totalPersonal > 50000) {
      insights.add("Spending is above average for this period. Consider reviewing 'Essentials' vs 'Luxuries'.");
    } else {
      insights.add("Spending is well-maintained and within standard household limits.");
    }

    // Category Insight
    final categories = <String, double>{};
    for (var e in [...shared, ...personal.map((p) => ExpenseData(id: p.id, title: p.title, amount: p.amount, description: p.description ?? "", category: p.category, selectedRoommateIds: const [], splitType: SplitType.equal, customSplits: const {}, paidBy: "", payerName: "", createdAt: p.createdAt))]) {
      categories[e.category] = (categories[e.category] ?? 0) + e.amount;
    }

    if (categories.isNotEmpty) {
      final topCategory = categories.entries.reduce((a, b) => a.value > b.value ? a : b);
      insights.add("${topCategory.key} account for ${(topCategory.value / (totalShared + totalPersonal) * 100).toStringAsFixed(1)}% of your total spending.");
    }

    // Settlement Insight
    if (shared.isNotEmpty) {
      final payers = <String, int>{};
      for (var e in shared) {
        payers[e.payerName ?? "Unknown"] = (payers[e.payerName ?? "Unknown"] ?? 0) + 1;
      }
      if (payers.length == 1) {
        insights.add("Most shared expenses were paid by one person. Settling up monthly is recommended to avoid debt accumulation.");
      }
    }

    if (personal.length > shared.length * 2) {
      insights.add("You have significantly more personal expenses than shared ones. This shows a healthy individual financial independence within the roomspace.");
    }

    return insights;
  }
}
