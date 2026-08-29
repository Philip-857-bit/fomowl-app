import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fomowl_wallet/utils/toast_utils.dart';
import 'package:fomowl_wallet/constants/app_colors.dart';
import 'package:flutter/material.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel('PonnamKarthik/fluttertoast');
  final List<MethodCall> log = <MethodCall>[];

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          log.add(methodCall);
          return true;
        });
  });

  tearDown(() {
    log.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('showSuccess shows success toast', () {
    ToastUtils.showSuccess('Success!');
    expect(log.length, 2);
    expect(log[0].method, 'cancel');
    expect(log[1].method, 'showToast');
    expect(log[1].arguments['msg'], 'Success!');
    // ignore: deprecated_member_use
    expect(log[1].arguments['bgcolor'], AppColors.success.value);
    // ignore: deprecated_member_use
    expect(log[1].arguments['textcolor'], Colors.white.value);
    expect(log[1].arguments['gravity'], 'bottom'); // ToastGravity.BOTTOM
    expect(log[1].arguments['time'], 1); // Toast.LENGTH_SHORT
    expect(log[1].arguments['fontSize'], 14.0);
  });

  test('showError shows error toast', () {
    ToastUtils.showError('Error!');
    expect(log.length, 2);
    expect(log[0].method, 'cancel');
    expect(log[1].method, 'showToast');
    expect(log[1].arguments['msg'], 'Error!');
    // ignore: deprecated_member_use
    expect(log[1].arguments['bgcolor'], AppColors.error.value);
    // ignore: deprecated_member_use
    expect(log[1].arguments['textcolor'], Colors.white.value);
    expect(log[1].arguments['gravity'], 'bottom'); // ToastGravity.BOTTOM
    expect(log[1].arguments['time'], 1); // Toast.LENGTH_SHORT
    expect(log[1].arguments['fontSize'], 14.0);
  });

  test('showInfo shows info toast', () {
    ToastUtils.showInfo('Info!');
    expect(log.length, 2);
    expect(log[0].method, 'cancel');
    expect(log[1].method, 'showToast');
    expect(log[1].arguments['msg'], 'Info!');
    expect(
      log[1].arguments['bgcolor'],
      // ignore: deprecated_member_use
      Colors.white.withOpacity(0.9).value,
    );
    // ignore: deprecated_member_use
    expect(log[1].arguments['textcolor'], Colors.black.value);
    expect(log[1].arguments['gravity'], 'bottom'); // ToastGravity.BOTTOM
    expect(log[1].arguments['time'], 1); // Toast.LENGTH_SHORT
    expect(log[1].arguments['fontSize'], 14.0);
  });
}
