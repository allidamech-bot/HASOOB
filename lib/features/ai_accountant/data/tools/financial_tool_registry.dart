class FinancialToolDefinition {
  final String name;
  final String description;
  final Map<String, dynamic> parameters;

  const FinancialToolDefinition({
    required this.name,
    required this.description,
    required this.parameters,
  });
}

class FinancialToolRegistry {
  static const Map<String, FinancialToolDefinition> _tools = {
    'getIncome': FinancialToolDefinition(
      name: 'getIncome',
      description: 'Retrieve income/sales transactions for a business within an optional date range',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'from': {'type': 'string', 'format': 'date-time', 'description': 'Start date filter (optional)'},
          'to': {'type': 'string', 'format': 'date-time', 'description': 'End date filter (optional)'},
          'limit': {'type': 'integer', 'description': 'Maximum number of records to return', 'default': 100},
        },
        'required': ['businessId'],
      },
    ),
    'getExpenses': FinancialToolDefinition(
      name: 'getExpenses',
      description: 'Retrieve expense transactions for a business within an optional date range',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'from': {'type': 'string', 'format': 'date-time', 'description': 'Start date filter (optional)'},
          'to': {'type': 'string', 'format': 'date-time', 'description': 'End date filter (optional)'},
          'limit': {'type': 'integer', 'description': 'Maximum number of records to return', 'default': 100},
        },
        'required': ['businessId'],
      },
    ),
    'getInvoices': FinancialToolDefinition(
      name: 'getInvoices',
      description: 'Retrieve invoices for a business, optionally filtered by status',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'status': {'type': 'string', 'description': 'Invoice status filter: draft, issued, paid, overdue (optional)'},
          'limit': {'type': 'integer', 'description': 'Maximum number of records to return', 'default': 100},
        },
        'required': ['businessId'],
      },
    ),
    'getCustomers': FinancialToolDefinition(
      name: 'getCustomers',
      description: 'Retrieve customers for a business, optionally filtered by search query',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'searchQuery': {'type': 'string', 'description': 'Search term for customer name or phone (optional)'},
          'limit': {'type': 'integer', 'description': 'Maximum number of records to return', 'default': 100},
        },
        'required': ['businessId'],
      },
    ),
    'getProducts': FinancialToolDefinition(
      name: 'getProducts',
      description: 'Retrieve products for a business, optionally filtered by search query or low stock status',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'searchQuery': {'type': 'string', 'description': 'Search term for product name (optional)'},
          'lowStockOnly': {'type': 'boolean', 'description': 'Return only products with low stock', 'default': false},
          'limit': {'type': 'integer', 'description': 'Maximum number of records to return', 'default': 100},
        },
        'required': ['businessId'],
      },
    ),
    'getFinancialSummary': FinancialToolDefinition(
      name: 'getFinancialSummary',
      description: 'Get aggregated financial summary including income, expenses, profit margin, and accounts receivable',
      parameters: {
        'type': 'object',
        'properties': {
          'businessId': {'type': 'string', 'description': 'Business identifier'},
          'from': {'type': 'string', 'format': 'date-time', 'description': 'Start date filter (optional)'},
          'to': {'type': 'string', 'format': 'date-time', 'description': 'End date filter (optional)'},
        },
        'required': ['businessId'],
      },
    ),
  };

  static List<FinancialToolDefinition> getAllTools() => _tools.values.toList();

  static FinancialToolDefinition? getTool(String name) => _tools[name];

  static List<Map<String, dynamic>> toGeminiFunctionDeclarations() {
    return _tools.values.map((tool) => {
      'name': tool.name,
      'description': tool.description,
      'parameters': tool.parameters,
    }).toList();
  }
}