import 'package:flutter/material.dart';
import 'package:shop/constants.dart';
import 'package:shop/entry_point.dart';
import 'package:shop/screens/address/views/address_map_picker_screen.dart';
import 'package:shop/screens/vendor/vendor_customer_detail_screen.dart';
import 'package:shop/screens/vendor/vendor_customers_screen.dart';
import 'package:shop/screens/vendor/vendor_earnings_screen.dart';
import 'package:shop/screens/vendor/vendor_inventory_screen.dart';
import 'package:shop/screens/vendor/vendor_ticket_detail_screen.dart';
import 'package:shop/screens/vendor/vendor_tickets_screen.dart';
import 'package:shop/services/vendor_service.dart';

import 'screen_export.dart';

// Yuo will get 50+ screens and more once you have the full template
// 🔗 Full template: https://theflutterway.gumroad.com/l/fluttershop

// NotificationPermissionScreen()
// PreferredLanguageScreen()
// SelectLanguageScreen()
// SignUpVerificationScreen()
// ProfileSetupScreen()
// VerificationMethodScreen()
// OtpScreen()
// SetNewPasswordScreen()
// DoneResetPasswordScreen()
// TermsOfServicesScreen()
// SetupFingerprintScreen()
// SetupFingerprintScreen()
// SetupFingerprintScreen()
// SetupFingerprintScreen()
// SetupFaceIdScreen()
// OnSaleScreen()
// BannerLStyle2()
// BannerLStyle3()
// BannerLStyle4()
// SearchScreen()
// SearchHistoryScreen()
// NotificationsScreen()
// EnableNotificationScreen()
// NoNotificationScreen()
// NotificationOptionsScreen()
// ProductInfoScreen()
// ShippingMethodsScreen()
// ProductReviewsScreen()
// SizeGuideScreen()
// BrandScreen()
// CartScreen()
// EmptyCartScreen()
// PaymentMethodScreen()
// ThanksForOrderScreen()
// CurrentPasswordScreen()
// EditUserInfoScreen()
// OrdersScreen()
// OrderProcessingScreen()
// OrderDetailsScreen()
// CancleOrderScreen()
// DelivereOrdersdScreen()
// AddressesScreen()
// NoAddressScreen()
// AddNewAddressScreen()
// ServerErrorScreen()
// NoInternetScreen()
// ChatScreen()
// DiscoverWithImageScreen()
// SubDiscoverScreen()
// AddNewCardScreen()
// EmptyPaymentScreen()
// GetHelpScreen()

// ℹ️ All the comments screen are included in the full template
// 🔗 Full template: https://theflutterway.gumroad.com/l/fluttershop

Route<dynamic> generateRoute(RouteSettings settings) {
  switch (settings.name) {
    case onbordingScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OnBordingScreen(),
      );
    // case preferredLanuageScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const PreferredLanguageScreen(),
    //   );
    case logInScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const LoginScreen(),
      );
    case signUpScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const SignUpScreen(),
      );
    // case profileSetupScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const ProfileSetupScreen(),
    //   );
    case passwordRecoveryScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const PasswordRecoveryScreen(),
      );
    // case verificationMethodScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const VerificationMethodScreen(),
    //   );
    // case otpScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const OtpScreen(),
    //   );
    // case newPasswordScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SetNewPasswordScreen(),
    //   );
    // case doneResetPasswordScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const DoneResetPasswordScreen(),
    //   );
    // case termsOfServicesScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const TermsOfServicesScreen(),
    //   );
    // case noInternetScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const NoInternetScreen(),
    //   );
    // case serverErrorScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const ServerErrorScreen(),
    //   );
    // case signUpVerificationScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SignUpVerificationScreen(),
    //   );
    // case setupFingerprintScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SetupFingerprintScreen(),
    //   );
    // case setupFaceIdScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SetupFaceIdScreen(),
    //   );
    case productDetailsScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          // String product id (water flow) or legacy bool availability flag.
          final args = settings.arguments;
          if (args is String) {
            return ProductDetailsScreen(productId: args);
          }
          return ProductDetailsScreen(
              isProductAvailable: args as bool? ?? true);
        },
      );
    case homeScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const HomeScreen(),
      );
    // case brandScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const BrandScreen(),
    //   );
    // case discoverWithImageScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const DiscoverWithImageScreen(),
    //   );
    // case subDiscoverScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SubDiscoverScreen(),
    //   );
    case discoverScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const DiscoverScreen(),
      );
    case searchScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          final args = settings.arguments;
          return SearchScreen(
              initialQuery: args is String ? args : "");
        },
      );
    // case searchHistoryScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SearchHistoryScreen(),
    //   );
    case entryPointScreenRoute:
      final parsed = parseEntryPointArgs(settings.arguments);
      // Keep OrdersScreen's existing ModalRoute auto-open working: it
      // reads a bare String or Map['orderId'], so alias openOrderId.
      // Settings are forwarded (previously dropped) so both EntryPoint
      // and the embedded OrdersScreen see the same arguments.
      final normalized = <String, dynamic>{
        'tab': parsed.tab,
        if (parsed.openOrderId != null) ...{
          'openOrderId': parsed.openOrderId,
          'orderId': parsed.openOrderId,
        },
        'showPlacedToast': parsed.showPlacedToast,
      };
      return MaterialPageRoute(
        settings: RouteSettings(name: settings.name, arguments: normalized),
        builder: (context) => EntryPoint(
          initialTab: parsed.tab,
          openOrderId: parsed.openOrderId,
          showPlacedToast: parsed.showPlacedToast,
        ),
      );
    case profileScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const ProfileScreen(),
      );
    // case getHelpScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const GetHelpScreen(),
    //   );
    case getHelpScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const HelpScreen(),
      );
    // case chatScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const ChatScreen(),
    //   );
    case userInfoScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const UserInfoScreen(),
      );
    // case currentPasswordScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const CurrentPasswordScreen(),
    //   );
    // case editUserInfoScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const EditUserInfoScreen(),
    //   );
    case notificationsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const NotificationsScreen(),
      );
    case enableNotificationScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EnableNotificationScreen(),
      );
    case notificationOptionsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const NotificationOptionsScreen(),
      );
    // case selectLanguageScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const SelectLanguageScreen(),
    //   );
    // case noAddressScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const NoAddressScreen(),
    //   );
    case addressesScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const AddressesScreen(),
      );
    case addressMapPickerScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const AddressMapPickerScreen(),
      );
    // case addNewAddressesScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const AddNewAddressScreen(),
    //   );
    case ordersScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const OrdersScreen(),
      );
    // case orderProcessingScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const OrderProcessingScreen(),
    //   );
    // case orderDetailsScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const OrderDetailsScreen(),
    //   );
    // case cancleOrderScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const CancleOrderScreen(),
    //   );
    // case deliveredOrdersScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const DelivereOrdersdScreen(),
    //   );
    // case cancledOrdersScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const CancledOrdersScreen(),
    //   );
    case preferencesScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const PreferencesScreen(),
      );
    // case emptyPaymentScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const EmptyPaymentScreen(),
    //   );
    case emptyWalletScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const EmptyWalletScreen(),
      );
    case walletScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const WalletScreen(),
      );
    case cartScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const CartScreen(),
      );
    case orderTypeScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          final args =
              settings.arguments as Map<String, dynamic>? ?? const {};
          return OrderTypeScreen(
            productId: args['productId'] as String? ?? "wd-20l-refill",
            qty: args['qty'] as int? ?? 1,
          );
        },
      );
    case subscriptionConfigScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          final args =
              settings.arguments as Map<String, dynamic>? ?? const {};
          return SubscriptionConfigScreen(
            productId: args['productId'] as String? ?? "wd-20l-refill",
            qty: args['qty'] as int? ?? 1,
          );
        },
      );
    case subscriptionsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const SubscriptionsScreen(),
      );
    case paymentMethodsScreenRoute:
      return MaterialPageRoute(
        builder: (context) =>
            PaymentMethodsScreen(initial: settings.arguments as String?),
      );
    case vendorHomeScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const VendorHomeScreen(),
      );
    case vendorCustomersScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const VendorCustomersScreen(
            service: VendorService()),
      );
    case vendorCustomerDetailScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          final args = settings.arguments;
          if (args is VendorCustomer) {
            return VendorCustomerDetailScreen(customer: args);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Customer not found. Open a customer from the customers list.',
              ),
            ),
          );
        },
      );
    case vendorEarningsScreenRoute:
      return MaterialPageRoute(
        builder: (context) =>
            const VendorEarningsScreen(service: VendorService()),
      );
    case vendorInventoryScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const VendorInventoryScreen(),
      );
    case vendorTicketsScreenRoute:
      return MaterialPageRoute(
        builder: (context) => const VendorTicketsScreen(),
      );
    case vendorTicketDetailScreenRoute:
      return MaterialPageRoute(
        builder: (context) {
          final args = settings.arguments;
          if (args is VendorTicket) {
            return VendorTicketDetailScreen(
                ticket: args, ticketId: args.id);
          }
          if (args is String && args.isNotEmpty) {
            return VendorTicketDetailScreen(ticketId: args);
          }
          return Scaffold(
            appBar: AppBar(title: const Text('Ticket')),
            body: const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Ticket not found. Open a ticket from the tickets list.',
              ),
            ),
          );
        },
      );
    // case paymentMethodScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const PaymentMethodScreen(),
    //   );
    // case addNewCardScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const AddNewCardScreen(),
    //   );
    // case thanksForOrderScreenRoute:
    //   return MaterialPageRoute(
    //     builder: (context) => const ThanksForOrderScreen(),
    //   );
    default:
      return MaterialPageRoute(
        builder: (context) => const NotFoundScreen(),
      );
  }
}

/// Simple 404: title + why + back-home action. No gradients, no
/// glassmorphism — plain theme text + primary button.
class NotFoundScreen extends StatelessWidget {
  const NotFoundScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Not found")),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(defaultPadding * 1.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Page not found",
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                "This page is not available. Check the address or go back home.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: defaultPadding),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pushNamedAndRemoveUntil(
                    context,
                    entryPointScreenRoute,
                    (_) => false,
                  ),
                  child: const Text("Back Home"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// MaterialApp `onUnknownRoute` — handles pushes to names that
/// [generateRoute] does not know (generateRoute's default above covers
/// the rest).
Route<dynamic> onUnknownRoute(RouteSettings settings) {
  return MaterialPageRoute(
    settings: settings,
    builder: (context) => const NotFoundScreen(),
  );
}
