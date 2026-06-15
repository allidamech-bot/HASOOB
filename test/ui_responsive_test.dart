import 'package:flutter_test/flutter_test.dart';
import 'package:hasoob_app/core/ui/responsive.dart';
import 'package:hasoob_app/core/ui/ui_tokens.dart';

void main() {
  group('UIResponsive', () {
    test('uses UITokens breakpoints for width classification', () {
      expect(UIResponsive.isPhoneWidth(UITokens.bpMobile - 1), isTrue);
      expect(UIResponsive.isPhoneWidth(UITokens.bpMobile), isFalse);

      expect(UIResponsive.isMobileWidth(UITokens.bpTablet - 1), isTrue);
      expect(UIResponsive.isMobileWidth(UITokens.bpTablet), isFalse);

      expect(UIResponsive.isTabletWidth(UITokens.bpTablet), isTrue);
      expect(UIResponsive.isTabletWidth(UITokens.bpSmallDesktop), isFalse);

      expect(UIResponsive.isDesktopWidth(UITokens.bpSmallDesktop), isTrue);
      expect(UIResponsive.isWideDesktopWidth(UITokens.bpDesktop), isTrue);
      expect(UIResponsive.isLargeDesktopWidth(UITokens.bpLargeDesktop), isTrue);
    });
  });
}
