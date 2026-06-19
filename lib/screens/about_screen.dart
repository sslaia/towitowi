import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../widgets/top_bar.dart';

class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: TopBar(
        title: 'about.title'.tr(),
        border: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          color: theme.colorScheme.onSurface,
          iconSize: 20.0,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 36.0),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // App Icon Showcase with golden premium drop shadow
                  Container(
                    width: 120.0,
                    height: 120.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(28.0),
                      border: Border.all(
                        color: theme.colorScheme.primaryContainer,
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.15),
                          blurRadius: 30.0,
                          spreadRadius: 3.0,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26.0),
                      child: Image.asset(
                        'assets/icon/app_icon.png',
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24.0),
                  
                  // App Title
                  Text(
                    'app_title'.tr(),
                    style: theme.textTheme.displayLarge?.copyWith(
                      fontSize: 36.0,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 4.0),
                  
                  // App Version
                  Text(
                    'about.version'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 32.0),
                  
                  // Brand Story & Description Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24.0),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(
                        color: theme.colorScheme.outlineVariant.withValues(alpha: 0.1),
                        width: 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.wb_twighlight,
                          color: theme.colorScheme.primaryContainer,
                          size: 32.0,
                        ),
                        const SizedBox(height: 16.0),
                        Text(
                          'about.description'.tr(),
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.6,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.9),
                            fontSize: 15.0,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48.0),
                  
                  // License Button
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: theme.colorScheme.primaryContainer,
                      side: BorderSide(
                        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: 'app_title'.tr(),
                        applicationVersion: '0.1.0',
                        applicationIcon: Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Container(
                            width: 64.0,
                            height: 64.0,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12.0),
                              border: Border.all(
                                color: theme.colorScheme.primaryContainer,
                                width: 1.0,
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(11.0),
                              child: Image.asset('assets/icon/app_icon.png'),
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.description_outlined, size: 18.0),
                    label: Text(
                      'about.view_licenses'.tr().toUpperCase(),
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48.0),
                  
                  // Copyright info
                  Text(
                    'about.copyright'.tr(),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                      fontSize: 12.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
