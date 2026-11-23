import 'package:flutter/material.dart';

import '../locale_controller.dart';

/// Each language's name in its own language, keyed by language code.
const Map<String, String> _nativeNames = {
  'vi': 'Tiếng Việt',
  'en': 'English',
  'de': 'Deutsch',
  'es': 'Español',
  'fr': 'Français',
  'ru': 'Русский',
  'lo': 'ລາວ',
  'ja': '日本語',
  'zh': '中文',
  'ko': '한국어',
};

/// A globe button that opens a menu of every supported language.
///
/// Drop it into an `AppBar.actions`. It reads and sets
/// [LocaleController.instance]; the current language shows a check mark.
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key, this.iconColor});

  /// Colour of the globe icon; defaults to the surrounding icon theme.
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final controller = LocaleController.instance;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final current = controller.locale.languageCode;
        return PopupMenuButton<Locale>(
          icon: Icon(Icons.language, color: iconColor),
          onSelected: controller.setLocale,
          itemBuilder: (context) => [
            for (final locale in LocaleController.supported)
              PopupMenuItem<Locale>(
                value: locale,
                child: Semantics(
                  selected: locale.languageCode == current,
                  child: Row(
                    children: [
                      SizedBox(
                        width: 24,
                        child: locale.languageCode == current
                            ? const Icon(Icons.check, size: 18)
                            : null,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          _nativeNames[locale.languageCode] ??
                              locale.languageCode,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
