import 'package:flutter/material.dart';

class ResponsiveLayout {
  final BuildContext context;
  ResponsiveLayout(this.context);

  bool get isMobile => MediaQuery.of(context).size.width < 800 || MediaQuery.of(context).size.height < 500;
  bool get isTablet => MediaQuery.of(context).size.width >= 800 && MediaQuery.of(context).size.width < 1200 && MediaQuery.of(context).size.height >= 500;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1200 && MediaQuery.of(context).size.height >= 500;

  double get margin => isMobile ? 24.0 : 64.0;
  double get maxContainerWidth => 1120.0;
  double get unit => 8.0;
  double get gutter => 32.0;

  EdgeInsets get horizontalPadding => EdgeInsets.symmetric(horizontal: margin);
}

typedef ResponsiveLayoutWidgetBuilder = Widget Function(
  BuildContext context,
  ResponsiveLayout layout,
);

class ResponsiveBuilder extends StatelessWidget {
  final ResponsiveLayoutWidgetBuilder builder;

  const ResponsiveBuilder({super.key, required this.builder});

  @override
  Widget build(BuildContext context) {
    return builder(context, ResponsiveLayout(context));
  }
}
