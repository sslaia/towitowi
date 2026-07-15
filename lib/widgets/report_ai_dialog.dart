import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:url_launcher/url_launcher.dart';

void showReportAiDialog(BuildContext context, {String? prompt, String? output}) {
  showDialog(
    context: context,
    builder: (BuildContext context) {
      final theme = Theme.of(context);

      return AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16.0),
        ),
        title: Row(
          children: [
            Icon(
              Icons.report_problem_outlined,
              color: theme.colorScheme.error,
            ),
            const SizedBox(width: 12.0),
            Expanded(
              child: Text(
                'about.report_dialog_title'.tr(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'about.report_dialog_message'.tr(),
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
                  icon: const Icon(Icons.gavel_outlined),
                  label: Text(
                    'about.report_to_google'.tr(),
                    style: TextStyle(
                      color: theme.colorScheme.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final url = Uri.parse('https://support.google.com/legal/answer/13531384');
                    if (await canLaunchUrl(url)) {
                      await launchUrl(url, mode: LaunchMode.externalApplication);
                    }
                  },
                ),
                const SizedBox(height: 12.0),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.error,
                    foregroundColor: theme.colorScheme.onError,
                    padding: const EdgeInsets.symmetric(vertical: 12.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  icon: const Icon(Icons.email_outlined),
                  label: Text(
                    'about.report_to_developer'.tr(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onPressed: () async {
                    Navigator.pop(context);
                    final Uri emailUri = Uri(
                      scheme: 'mailto',
                      path: 'slaia@yahoo.com',
                      queryParameters: {
                        'subject': 'TowiTowi - AI Output Report',
                        'body': 'Inappropriate AI Content Report\n\n'
                            '${prompt != null ? "User Thoughts:\n$prompt\n\n" : ""}'
                            '${output != null ? "AI Output:\n$output\n\n" : ""}'
                            'Reason for report:\n'
                      },
                    );
                    if (await canLaunchUrl(emailUri)) {
                      await launchUrl(emailUri);
                    }
                  },
                ),
                const SizedBox(height: 12.0),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 10.0),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'edit.cancel'.tr(),
                    style: TextStyle(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
