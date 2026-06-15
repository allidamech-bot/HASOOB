import 'package:flutter/widgets.dart';

import 'ui_tokens.dart';

class UIResponsive {
  const UIResponsive._();

  static const double phoneBreakpoint = UITokens.bpMobile;
  static const double tabletBreakpoint = UITokens.bpTablet;
  static const double smallDesktopBreakpoint = UITokens.bpSmallDesktop;
  static const double desktopBreakpoint = UITokens.bpDesktop;
  static const double largeDesktopBreakpoint = UITokens.bpLargeDesktop;

  static double widthOf(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static bool isPhoneWidth(double width) => width < UITokens.bpMobile;
  static bool isPhone(BuildContext context) => isPhoneWidth(widthOf(context));

  static bool isMobileWidth(double width) => width < UITokens.bpTablet;
  static bool isMobile(BuildContext context) => isMobileWidth(widthOf(context));

  static bool isTabletWidth(double width) =>
      width >= UITokens.bpTablet && width < UITokens.bpSmallDesktop;
  static bool isTablet(BuildContext context) => isTabletWidth(widthOf(context));

  static bool isDesktopWidth(double width) => width >= UITokens.bpSmallDesktop;
  static bool isDesktop(BuildContext context) =>
      isDesktopWidth(widthOf(context));

  static bool isWideDesktopWidth(double width) => width >= UITokens.bpDesktop;
  static bool isWideDesktop(BuildContext context) =>
      isWideDesktopWidth(widthOf(context));

  static bool isLargeDesktopWidth(double width) =>
      width >= UITokens.bpLargeDesktop;
  static bool isLargeDesktop(BuildContext context) =>
      isLargeDesktopWidth(widthOf(context));

  static double contentMaxWidth(BuildContext context) {
    final width = widthOf(context);
    if (isLargeDesktopWidth(width)) return UITokens.bpLargeDesktop;
    if (isDesktopWidth(width)) return UITokens.bpDesktop;
    return double.infinity;
  }

  static double responsiveHorizontalPadding(BuildContext context) {
    final width = widthOf(context);
    if (isDesktopWidth(width)) return UITokens.space3xl;
    return UITokens.mobileHorizontalPadding;
  }

  static int responsiveColumns(
    BuildContext context, {
    int phone = 1,
    int mobile = 1,
    int tablet = 2,
    int desktop = 3,
    int largeDesktop = 4,
  }) {
    final width = widthOf(context);
    if (isLargeDesktopWidth(width)) return largeDesktop;
    if (isDesktopWidth(width)) return desktop;
    if (isTabletWidth(width)) return tablet;
    if (isPhoneWidth(width)) return phone;
    return mobile;
  }
}
