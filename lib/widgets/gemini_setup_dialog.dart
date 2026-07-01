import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../screens/guide_screen.dart';

void showGeminiSetupDialog(BuildContext context) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final theme = Theme.of(context);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);

      return AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: [
            Icon(
              Icons.auto_awesome,
              color: theme.colorScheme.primaryContainer,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                'gemini_alert.title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'gemini_alert.message'.tr(),
                style: TextStyle(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24.0),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                ),
                icon: const Icon(Icons.help_outline_rounded),
                label: Text(
                  'gemini_alert.go_to_guide'.tr(),
                  style: TextStyle(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GuideScreen()),
                  );
                },
              ),
              const SizedBox(height: 12.0),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                      ),
                      onPressed: () async {
                        await settingsProvider.disableGeminiSetupAlertForever();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'gemini_alert.hide_forever'.tr(),
                        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8.0),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.secondary,
                        side: BorderSide(color: theme.colorScheme.secondary.withValues(alpha: 0.3)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10.0),
                      ),
                      onPressed: () async {
                        await settingsProvider.snoozeGeminiSetupAlert(3); // Snooze for 3 days
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        'gemini_alert.remind_me'.tr(),
                        style: const TextStyle(fontSize: 12.0, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'gemini_alert.close'.tr(),
              style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
      );
    },
  );
}
