import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class AppFrame extends StatelessWidget {
  const AppFrame({super.key, required this.child, this.background});

  final Widget child;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final framed = constraints.maxWidth > 430;
            return Container(
              width: constraints.maxWidth < 430 ? constraints.maxWidth : 430,
              height: framed && constraints.maxHeight > 932
                  ? 932
                  : constraints.maxHeight,
              color: background ?? AppColors.softScreen,
              child: child,
            );
          },
        ),
      ),
    );
  }
}
