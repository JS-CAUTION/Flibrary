import 'package:flutter_test/flutter_test.dart';
import 'package:course_schedule_app/services/edu_login_scripts.dart';
import 'package:course_schedule_app/services/credential_storage_service.dart';

void main() {
  group('EduLoginScripts.fillScript', () {
    test('embeds account/password with JSON escaping', () {
      final script = EduLoginScripts.fillScript('202408060135', 'P@ss"word');
      expect(script, contains('userAccount'));
      expect(script, contains('userPassword'));
      // 引号必须被转义,不能直接嵌入脚本
      expect(script, contains(r'P@ss\"word'));
      expect(script, isNot(contains('P@ss"word')));
    });

    test('handles plain credentials', () {
      final script = EduLoginScripts.fillScript('abc', '123');
      expect(script, contains('"abc"'));
      expect(script, contains('"123"'));
    });
  });

  group('EduLoginScripts.parseCaptureMessage', () {
    test('parses valid capture payload', () {
      final cred = EduLoginScripts.parseCaptureMessage(
          '{"account":"202408060135","password":"secret"}');
      expect(cred, isNotNull);
      expect(cred!.account, '202408060135');
      expect(cred.password, 'secret');
    });

    test('returns null for empty or malformed messages', () {
      expect(EduLoginScripts.parseCaptureMessage(''), isNull);
      expect(EduLoginScripts.parseCaptureMessage('not json'), isNull);
      expect(EduLoginScripts.parseCaptureMessage('{"account":"","password":""}'),
          isNull);
      expect(EduLoginScripts.parseCaptureMessage('{"account":"a"}'), isNull);
    });
  });

  group('EduLoginScripts scripts structure', () {
    test('isLoginPageScript probes account/password inputs', () {
      expect(EduLoginScripts.isLoginPageScript, contains('userAccount'));
      expect(EduLoginScripts.isLoginPageScript, contains('userPassword'));
    });

    test('captureScript is idempotent and posts via channel', () {
      expect(EduLoginScripts.captureScript, contains('__eduCaptureInstalled'));
      expect(EduLoginScripts.captureScript,
          contains(EduLoginScripts.captureChannelName));
      expect(EduLoginScripts.captureScript, contains('postMessage'));
      expect(EduLoginScripts.captureScript, contains('addEventListener'));
    });
  });

  group('CredentialStorageService', () {
    test('load returns null when secure storage is unavailable', () async {
      // 单测环境无原生通道,容错后应静默返回 null 而非抛异常
      final cred = await CredentialStorageService.load();
      expect(cred, isNull);
    });

    test('save/clear do not throw without native channel', () async {
      await CredentialStorageService.save('202408060135', 'secret');
      await CredentialStorageService.clear();
    });

    test('loadAccountOnly returns null when unavailable', () async {
      expect(await CredentialStorageService.loadAccountOnly(), isNull);
    });
  });
}
