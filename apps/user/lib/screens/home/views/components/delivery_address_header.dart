import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../../constants.dart';
import '../../../../models/order_model.dart';
import '../../../../route/route_constants.dart';

/// "Delivering to" header. Address comes from the repository layer
/// (currently [defaultAddress]); tap opens the address book.
class DeliveryAddressHeader extends StatelessWidget {
  const DeliveryAddressHeader({super.key, this.onChange});

  final VoidCallback? onChange;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          defaultPadding, defaultPadding, defaultPadding, defaultPadding / 2),
      child: Row(
        children: [
          SvgPicture.asset(
            "assets/icons/Location.svg",
            height: 22,
            colorFilter:
                const ColorFilter.mode(primaryColor, BlendMode.srcIn),
          ),
          const SizedBox(width: defaultPadding / 2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Delivering to",
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium!
                      .copyWith(fontSize: 12),
                ),
                Text(
                  "${defaultAddress.label} · ${defaultAddress.line}, ${defaultAddress.city}",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onChange ??
                () => Navigator.pushNamed(context, addressesScreenRoute),
            child: const Text("Change"),
          ),
        ],
      ),
    );
  }
}
