import 'package:flutter/material.dart';

import '../constants.dart';

Future<dynamic> customModalBottomSheet(
  BuildContext context, {
  bool isDismissible = true,
  double? height,
  String? title,
  bool showClose = false,
  required Widget child,
}) {
  final showHeader = title != null || showClose;
  return showModalBottomSheet(
    context: context,
    clipBehavior: Clip.hardEdge,
    isScrollControlled: true,
    isDismissible: isDismissible,
    enableDrag: isDismissible,
    backgroundColor: Theme.of(context).scaffoldBackgroundColor,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(defaultBorderRadious * 2),
        topRight: Radius.circular(defaultBorderRadious * 2),
      ),
    ),
    builder: (context) => SizedBox(
      height: height ?? MediaQuery.of(context).size.height * 0.75,
      child: showHeader
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    defaultPadding * 1.5,
                    defaultPadding,
                    defaultPadding / 2,
                    0,
                  ),
                  child: Row(
                    children: [
                      if (title != null)
                        Expanded(
                          child: Text(
                            title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall!
                                .copyWith(fontWeight: FontWeight.w600),
                          ),
                        )
                      else
                        const Spacer(),
                      if (showClose)
                        IconButton(
                          tooltip: "Close",
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(child: child),
                ),
              ],
            )
          : child,
    ),
  );
}
