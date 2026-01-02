import 'package:flutter_test/flutter_test.dart';

import 'package:soko_seller_terminal/src/core/network/pos_dtos.dart';

void main() {
  test('PosSyncPullResponse parses expenses payload', () {
    final json = <String, dynamic>{
      'received_at': '2025-01-01T00:00:00Z',
      'since': '2025-01-01T00:00:00Z',
      'outlet_id': '1',
      'products': const [],
      'services': const [],
      'customers': const [],
      'suppliers': const [],
      'expenses': [
        {
          'id': 10,
          'client_expense_id': 'expense-local-1',
          'amount': 2500,
          'method': 'cash',
          'category': 'utilities',
          'supplier_id': null,
          'note': 'Water',
          'occurred_at': '2025-01-01T00:00:00Z',
          'updated_at': '2025-01-01T00:00:00Z',
        },
      ],
      'receipt_templates': const [],
      'quotation_templates': const [],
      'ledger_entries': const [],
      'seller_profile': null,
      'config': const {'outlet': null},
    };

    final parsed = PosSyncPullResponse.fromJson(json);
    expect(parsed.expenses, hasLength(1));
    expect(parsed.expenses.first.id, 10);
    expect(parsed.expenses.first.clientExpenseId, 'expense-local-1');
    expect(parsed.expenses.first.amount, 2500.0);
    expect(parsed.expenses.first.method, 'cash');
    expect(parsed.expenses.first.category, 'utilities');
    expect(parsed.expenses.first.note, 'Water');
  });
}

