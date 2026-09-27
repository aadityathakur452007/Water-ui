// Single demo seed (demo mode only). All demo branches in repositories
// and services derive from here via DemoStore; no per-file hardcoded
// seed rows. Live paths never touch this file.
//
// Orders are canonical maps readable by both Order.fromJson (user) and
// VendorOrder.fromJson (vendor): {id, type, status, total, slot,
// created_at, items:[{productId,name,qty,price}],
// address:{label,line,city}, customer:{name,phone,email}}.
// User vs vendor views are projections/filters of the same order list.

// Demo users — emails/roles match the demo login creds in AppConfig.
const demoUsers = [
  {
    'id': 'demo-user',
    'name': 'Demo User',
    'phone': '9000000001',
    'email': 'user@demo.local',
    'password': 'demo123',
    'role': 'user',
  },
  {
    'id': 'demo-vendor',
    'name': 'Demo Vendor',
    'phone': '9000000002',
    'email': 'vendor@demo.local',
    'password': 'vendor123',
    'role': 'vendor',
  },
];

const demoAddresses = [
  {
    'id': 'home',
    'label': 'Home',
    'line': '123, Example Colony',
    'city': 'Bhopal',
  },
];

const _demoCustomer = {
  'name': 'Demo User',
  'phone': '9000000001',
  'email': 'user@demo.local',
};

const demoOrders = [
  {
    'id': 'WD-00124',
    'type': 'one-time',
    'status': 'scheduled',
    'total': 66,
    'slot': 'Tomorrow • 8:00 AM',
    'created_at': 'Today',
    'items': [
      {
        'productId': 'wd-20l-refill',
        'name': '20L Water Refill (Own Container)',
        'qty': 2,
        'price': 28,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '123, Example Colony',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00119',
    'type': 'regular',
    'status': 'scheduled',
    'total': 70,
    'slot': 'Every Day • 8:00 AM',
    'created_at': '20 Sept',
    'items': [
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 2,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '123, Example Colony',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00122',
    'type': 'one-time',
    'status': 'preparing',
    'total': 40,
    'slot': 'Today • 12:00 PM',
    'created_at': 'Today',
    'items': [
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 1,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Office',
      'line': '45, Business Park',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00120',
    'type': 'one-time',
    'status': 'out_for_delivery',
    'total': 68,
    'slot': 'Today • 6:00 PM',
    'created_at': 'Today',
    'items': [
      {
        'productId': 'wd-20l-refill',
        'name': '20L Water Refill (Own Container)',
        'qty': 1,
        'price': 28,
      },
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 1,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '78, Shanti Nagar',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00118',
    'type': 'one-time',
    'status': 'delivered',
    'total': 100,
    'slot': 'Today • 8:00 AM',
    'created_at': 'Today',
    'items': [
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 3,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Shop',
      'line': '12, Market Road',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00115',
    'type': 'regular',
    'status': 'delivered',
    'total': 66,
    'slot': 'Today • 9:30 AM',
    'created_at': 'Today',
    'items': [
      {
        'productId': 'wd-20l-refill',
        'name': '20L Water Refill (Own Container)',
        'qty': 2,
        'price': 28,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '90, Lake View',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00110',
    'type': 'one-time',
    'status': 'cancelled',
    'total': 70,
    'slot': 'Yesterday • 8:00 AM',
    'created_at': '19 Sept',
    'items': [
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 2,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '33, Old Town',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
  {
    'id': 'WD-00098',
    'type': 'one-time',
    'status': 'cancelled',
    'total': 40,
    'slot': '10 Sept • 8:00 AM',
    'created_at': '9 Sept • 9:40 AM',
    'items': [
      {
        'productId': 'wd-20l-jar',
        'name': '20L Jar with Container',
        'qty': 1,
        'price': 30,
      },
    ],
    'address': {
      'label': 'Home',
      'line': '123, Example Colony',
      'city': 'Bhopal',
    },
    'customer': _demoCustomer,
  },
];

// User-shape subscriptions (parsed by `Subscription.fromJson`).
const demoUserSubscriptions = [
  {
    'id': 'SUB-042',
    'product_id': 'wd-20l-jar',
    'product_name': '20L Jar with Container',
    'quantity': 2,
    'frequency': 'every_day',
    'start_date': '25 September 2026',
    'delivery_time': '8:00 AM',
    'status': 'active',
    'next_delivery': 'Tomorrow • 8:00 AM',
  },
];

// Vendor-shape subscriptions (parsed by `VendorSubscription.fromJson`).
const demoVendorSubscriptions = [
  {
    'product_id': 'wd-20l-jar',
    'product_name': '20L Jar with Container',
    'quantity': 2,
    'frequency': 'Every Day',
    'status': 'active',
    'next_delivery': 'Tomorrow • 8:00 AM',
  },
  {
    'product_id': 'wd-20l-refill',
    'product_name': '20L Water Refill (Own Container)',
    'quantity': 1,
    'frequency': 'Alternate Days',
    'status': 'active',
    'next_delivery': 'Today • 12:00 PM',
  },
  {
    'product_id': 'wd-20l-refill',
    'product_name': '20L Water Refill (Own Container)',
    'quantity': 1,
    'frequency': 'Once a Week',
    'status': 'paused',
    'next_delivery': 'Monday • 8:00 AM',
  },
];

const demoDeliveryProgress = {
  'delivered': 18,
  'scheduled': 10,
  'skipped': 2,
  'amountPaid': 1080,
};
