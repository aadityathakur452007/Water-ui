import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shop/constants.dart';

import 'components/prederence_list_tile.dart';

/// Device-only preferences. There is no preference endpoint in the
/// backend, so choices persist via shared_preferences on this device.
class PreferencesScreen extends StatefulWidget {
  const PreferencesScreen({super.key});

  @override
  State<PreferencesScreen> createState() => _PreferencesScreenState();
}

class _PreferencesScreenState extends State<PreferencesScreen> {
  static const _defaults = [true, false, false, false];
  static const _keys = [
    'prefs_analytics',
    'prefs_personalization',
    'prefs_marketing',
    'prefs_social',
  ];
  var _active = [true, false, false, false];

  static const _items = [
    (
      title: "Analytics",
      subtitle:
          "Analytics cookies help us improve our application by collecting and reporting info on how you use it. They collect information in a way that does not directly identify anyone."
    ),
    (
      title: "Personalization",
      subtitle:
          "Personalisation cookies collect information about your use of this app in order to display content and experience that are relevant to you."
    ),
    (
      title: "Marketing",
      subtitle:
          "Marketing cookies collect information about your use of this and other apps to enable display ads and other marketing that is more relevant to you."
    ),
    (
      title: "Social media cookies",
      subtitle:
          "These cookies are set by a range of social media services that we have added to the site to enable you to share our content with your friends and networks."
    ),
  ];

  @override
  void initState() {
    super.initState();
    _restore();
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (var i = 0; i < _keys.length; i++) {
        _active[i] = prefs.getBool(_keys[i]) ?? _defaults[i];
      }
    });
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < _keys.length; i++) {
      await prefs.setBool(_keys[i], _active[i]);
    }
  }

  void _savedToast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), showCloseIcon: true),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Preferences"),
        actions: [
          TextButton(
            onPressed: () async {
              setState(() => _active = [..._defaults]);
              await _save();
              _savedToast("Preferences reset.");
            },
            child: const Text("Reset"),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: defaultPadding),
        child: Column(
          children: [
            for (var i = 0; i < _items.length; i++) ...[
              if (i > 0) const Divider(height: defaultPadding * 2),
              PreferencesListTile(
                titleText: _items[i].title,
                subtitleTxt: _items[i].subtitle,
                isActive: _active[i],
                press: () async {
                  setState(() => _active[i] = !_active[i]);
                  await _save();
                  _savedToast("Saved.");
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
