import 'package:flutter_test/flutter_test.dart';
import 'package:splitterbuddy/core/constants/app_constants.dart';

void main() {
  test('App constants definition', () {
    expect(AppConstants.appName, 'SplitterBud');
    expect(AppConstants.defaultCurrency, 'ETB');
    expect(AppConstants.maxWorkspaceMembers, 2);
    expect(AppConstants.inviteCodeLength, 6);
  });
}
