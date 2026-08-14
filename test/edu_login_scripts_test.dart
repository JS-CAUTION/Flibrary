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
    test('loadSelected/loadAll degrade to empty when storage unavailable',
        () async {
      // 单测环境无原生通道,容错后应静默返回而非抛异常
      expect(await CredentialStorageService.loadAll(), isEmpty);
      expect(await CredentialStorageService.loadSelected(), isNull);
      expect(await CredentialStorageService.loadSelectedAccount(), isNull);
      expect(await CredentialStorageService.loadSaveEnabled(), isFalse);
    });

    test('save/delete/clearAll/setSelected do not throw without native channel',
        () async {
      await CredentialStorageService.save('202408060135', 'secret');
      await CredentialStorageService.setSelected('202408060135');
      await CredentialStorageService.delete('202408060135');
      await CredentialStorageService.clearAll();
      await CredentialStorageService.setSaveEnabled(true);
    });

    test('mergeCredentials overwrites same account and puts it first', () {
      final list = [
        {'account': 'A1', 'password': 'old', 'updatedAt': ''},
        {'account': 'B2', 'password': 'b', 'updatedAt': ''},
      ];
      final merged = CredentialStorageService.mergeCredentials(
          list, {'account': 'A1', 'password': 'new', 'updatedAt': ''});
      expect(merged.length, 2);
      expect(merged.first['account'], 'A1');
      expect(merged.first['password'], 'new');
    });

    test('mergeCredentials appends new account at front', () {
      final merged = CredentialStorageService.mergeCredentials(
          [{'account': 'A1', 'password': 'a', 'updatedAt': ''}],
          {'account': 'C3', 'password': 'c', 'updatedAt': ''});
      expect(merged.length, 2);
      expect(merged.first['account'], 'C3');
    });

    test('encodeList/decodeList round-trip, corrupt input returns empty', () {
      final list = [
        {'account': 'A1', 'password': 'p"w', 'updatedAt': 't'},
      ];
      final decoded = CredentialStorageService.decodeList(
          CredentialStorageService.encodeList(list));
      expect(decoded, list);
      expect(CredentialStorageService.decodeList('not json'), isEmpty);
      expect(CredentialStorageService.decodeList('[]'), isEmpty);
      // 缺字段的条目被过滤
      expect(CredentialStorageService.decodeList('[{"account":""}]'), isEmpty);
    });
  });
}
