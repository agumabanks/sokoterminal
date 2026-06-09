import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/db/app_database.dart';

/// Product selected in Studio for template quick-apply and share flows.
final studioProductProvider = StateProvider<Item?>((ref) => null);