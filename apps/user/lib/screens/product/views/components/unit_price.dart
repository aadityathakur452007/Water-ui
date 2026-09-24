import 'package:flutter/material.dart';

import '../../../../constants.dart';
import '../../../../models/cart_model.dart';

class UnitPrice extends StatelessWidget {
  const UnitPrice({
    super.key,
    required this.price,
    this.priceAfterDiscount,
  });

  final double price;
  final double? priceAfterDiscount;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Unit price",
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: defaultPadding / 1),
        Text.rich(
          TextSpan(
            text: priceAfterDiscount == null
                ? "${inr(price)}  "
                : "${inr(priceAfterDiscount!)}  ",
            style: Theme.of(context).textTheme.titleLarge,
            children: [
              if (priceAfterDiscount != null)
                TextSpan(
                  text: inr(price),
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: Theme.of(context).textTheme.bodyMedium!.color,
                      decoration: TextDecoration.lineThrough),
                ),
            ],
          ),
        )
      ],
    );
  }
}
