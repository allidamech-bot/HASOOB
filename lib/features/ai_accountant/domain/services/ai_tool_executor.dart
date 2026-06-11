import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../data/tools/financial_tools.dart';
import '../../data/tools/financial_tool_registry.dart';

class ToolCall {
  final String name;
  final Map<String, dynamic> arguments;

  const ToolCall({required this.name, required this.arguments});

  factory ToolCall.fromJson(Map<String, dynamic> json) {
    return ToolCall(
      name: json['name']?.toString() ?? '',
      arguments: Map<String, dynamic>.from(json['args'] ?? json['arguments'] ?? {}),
    );
  }
}

class ToolResult {
  final String toolName;
  final bool success;
  final dynamic data;
  final String? error;

  const ToolResult({
    required this.toolName,
    required this.success,
    this.data,
    this.error,
  });

  Map<String, dynamic> toJson() => {
    'toolName': toolName,
    'success': success,
    'data': data,
    'error': error,
  };
}

class AiToolExecutor {
  final FinancialTools _tools;

  AiToolExecutor({FinancialTools? tools}) : _tools = tools ?? FinancialTools();

  Future<ToolResult> executeTool(ToolCall call) async {
    final toolDef = FinancialToolRegistry.getTool(call.name);
    if (toolDef == null) {
      return ToolResult(
        toolName: call.name,
        success: false,
        error: 'Unknown tool: ${call.name}',
      );
    }

    try {
      final businessId = call.arguments['businessId']?.toString();
      if (businessId == null || businessId.isEmpty) {
        return ToolResult(
          toolName: call.name,
          success: false,
          error: 'businessId is required',
        );
      }

      final from = _parseDate(call.arguments['from']);
      final to = _parseDate(call.arguments['to']);
      final limit = call.arguments['limit'] is int 
          ? call.arguments['limit'] as int 
          : int.tryParse(call.arguments['limit']?.toString() ?? '100') ?? 100;

      FinancialToolResult result;

      switch (call.name) {
        case 'getIncome':
          result = await _tools.getIncome(
            businessId: businessId,
            from: from,
            to: to,
            limit: limit,
          );
          break;
        case 'getExpenses':
          result = await _tools.getExpenses(
            businessId: businessId,
            from: from,
            to: to,
            limit: limit,
          );
          break;
        case 'getInvoices':
          result = await _tools.getInvoices(
            businessId: businessId,
            status: call.arguments['status']?.toString(),
            limit: limit,
          );
          break;
        case 'getCustomers':
          result = await _tools.getCustomers(
            businessId: businessId,
            searchQuery: call.arguments['searchQuery']?.toString(),
            limit: limit,
          );
          break;
        case 'getProducts':
          result = await _tools.getProducts(
            businessId: businessId,
            searchQuery: call.arguments['searchQuery']?.toString(),
            lowStockOnly: call.arguments['lowStockOnly'] == true,
            limit: limit,
          );
          break;
        case 'getFinancialSummary':
          result = await _tools.getFinancialSummary(
            businessId: businessId,
            from: from,
            to: to,
          );
          break;
        default:
          return ToolResult(
            toolName: call.name,
            success: false,
            error: 'Tool not implemented: ${call.name}',
          );
      }

      if (result.success) {
        return ToolResult(
          toolName: call.name,
          success: true,
          data: result.data,
        );
      } else {
        return ToolResult(
          toolName: call.name,
          success: false,
          error: result.error,
        );
      }
    } catch (e, stack) {
      debugPrint('[AiToolExecutor] Error executing tool ${call.name}: $e');
      debugPrint('$stack');
      return ToolResult(
        toolName: call.name,
        success: false,
        error: 'Execution error: $e',
      );
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    return DateTime.tryParse(value.toString());
  }

  static bool isGeminiToolCallResponse(String text) {
    try {
      final decoded = jsonDecode(text);
      return decoded is Map && decoded.containsKey('name') && decoded.containsKey('args');
    } catch (_) {
      return false;
    }
  }

  static ToolCall? parseToolCall(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map && decoded.containsKey('name')) {
        return ToolCall.fromJson(Map<String, dynamic>.from(decoded));
      }
    } catch (_) {}
    return null;
  }
}