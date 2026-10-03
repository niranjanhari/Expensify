const String defaultCurrency = '₹';

const List<String> paymentMethods = [
  'Cash',
  'UPI',
  'GPay',
  'Card',
  'Bank Transfer',
  'Other',
];

const List<Map<String, String>> defaultSeedTags = [
  {'name': 'Food', 'description': 'Meals, groceries, dining out, and snacks'},
  {'name': 'Transport', 'description': 'Fuel, public transit, rideshare, and parking'},
  {'name': 'Education', 'description': 'Courses, books, materials, and tuition'},
  {'name': 'Entertainment', 'description': 'Movies, concerts, gaming, and leisure'},
  {'name': 'Shopping', 'description': 'Clothing, electronics, and general merchandise'},
  {'name': 'Bills', 'description': 'Utilities, phone recharge, internet, and subscriptions'},
  {'name': 'Rent', 'description': 'Housing and rental payments'},
  {'name': 'Health', 'description': 'Medical, pharmacy, fitness, and health care'},
  {'name': 'Travel', 'description': 'Flights, lodging, vacations, and excursions'},
  {'name': 'Misc', 'description': 'Miscellaneous and uncategorized expenses'},
];
