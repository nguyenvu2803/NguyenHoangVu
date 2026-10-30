import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:nguyen_hoang_vu/core/api.dart';
import 'package:nguyen_hoang_vu/core/live.dart';
import 'package:nguyen_hoang_vu/core/chat.dart';

void main() {
  const endpoint = String.fromEnvironment('NHV_TEST_API_URL');
  const mailboxFile = String.fromEnvironment('NHV_TEST_MAILBOX_FILE');
  const faceFile = String.fromEnvironment('NHV_TEST_FACE_FILE');
  test(
    'Dart client and real Express agree on complete attendance workflow',
    () async {
      expect(Uri.parse(endpoint).host, '127.0.0.1');
      final admin = Api(endpoint: endpoint), worker = Api(endpoint: endpoint);
      addTearDown(admin.client.close);
      addTearDown(worker.client.close);
      Future<Json> verify(Api api, Json challenge, String email) async {
        final mailbox =
            jsonDecode(await File(mailboxFile).readAsString()) as List;
        final message = mailbox.lastWhere((m) => m['email'] == email);
        final result = Json.from(
          await api.request('POST', '/auth/verify-otp', {
            'challengeId': challenge['challengeId'],
            'code': message['code'],
          }),
        );
        api.acceptTokens(result);
        return Json.from(result['user']);
      }

      final adminUser = await verify(
        admin,
        Json.from(
          await admin.request('POST', '/auth/login', {
            'username': 'contract_admin',
            'password': 'Contract-test-password-29',
          }),
        ),
        'admin@example.test',
      );
      final office = Json.from(
        await admin.request('POST', '/branches', {
          'name': 'Contract Office',
          'address': 'Contract test only',
          'latitude': 10.8,
          'longitude': 106.7,
          'radiusMeters': 100,
        }),
      );
      await admin.request('PATCH', '/branches/${office['id']}', {
        'name': 'Updated Office',
      });
      final workerUser = await verify(
        worker,
        Json.from(
          await worker.request('POST', '/auth/register', {
            'fullName': 'Contract Worker',
            'username': 'contract_worker',
            'email': 'worker@example.test',
            'password': 'Contract-test-password-29',
          }),
        ),
        'worker@example.test',
      );
      expect(workerUser['status'], 'pending');
      await expectLater(
        worker.request('GET', '/dashboard'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      await admin.request('PATCH', '/employees/${workerUser['id']}', {
        'status': 'active',
        'branchId': office['id'],
      });
      final active = Json.from(await worker.request('GET', '/me'));
      expect(active['status'], 'active');
      final receiverChat = ChatController(worker, adminUser['id']);
      final senderChat = ChatController(admin, workerUser['id']);
      addTearDown(receiverChat.dispose);
      addTearDown(senderChat.dispose);
      final connected = Completer<void>(), received = Completer<void>();
      receiverChat.addListener(() {
        if (receiverChat.online && !connected.isCompleted) {
          connected.complete();
        }
        if (receiverChat.messages.any(
              (row) => row['text'] == 'Hello from the manager',
            ) &&
            !received.isCompleted) {
          received.complete();
        }
      });
      receiverChat.start();
      await connected.future.timeout(const Duration(seconds: 10));
      expect(await senderChat.send('Hello from the manager', 'en'), true);
      await received.future.timeout(const Duration(seconds: 10));
      expect(receiverChat.messages.single['sourceLanguage'], 'en');
      receiverChat.pause();
      final adminData = LiveData(admin, adminUser),
          workerData = LiveData(worker, active);
      await adminData.load();
      await workerData.load();
      await expectLater(
        worker.request('POST', '/branches', {'name': 'Forbidden'}),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 403)),
      );
      final now = DateTime.now().toUtc();
      final shift = Json.from(
        await admin.request('POST', '/shifts', {
          'title': 'Contract Shift',
          'branchId': office['id'],
          'employeeId': active['id'],
          'startsAt': now
              .subtract(const Duration(minutes: 5))
              .toIso8601String(),
          'endsAt': now.add(const Duration(minutes: 5)).toIso8601String(),
        }),
      );
      await admin.request('PATCH', '/shifts/${shift['id']}', {
        'title': 'Updated Shift',
      });
      await workerData.load();
      expect(
        decodeShiftQr(encodeShiftQr(shift['id']), workerData.ownShifts),
        shift['id'],
      );
      final punch = <String, dynamic>{
        'shiftId': shift['id'],
        'latitude': 10.8,
        'longitude': 106.7,
        'accuracyMeters': 5,
      };
      await worker.request('POST', '/attendance/check-in', punch);
      await expectLater(
        worker.request('POST', '/attendance/check-in', punch),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
      await worker.request('POST', '/attendance/check-out', punch);
      final correction = Json.from(
        await worker.request('POST', '/corrections', {
          'shiftId': shift['id'],
          'reason': 'Contract timing adjustment',
          'requestedCheckIn': now
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
        }),
      );
      await worker.request('PATCH', '/corrections/${correction['id']}', {
        'reason': 'Updated correction reason',
      });
      await admin.request('PATCH', '/corrections/${correction['id']}', {
        'status': 'approved',
        'resolutionNote': 'Contract approval',
      });
      final share = Json.from(
        await worker.request('POST', '/location-shares', {
          'latitude': 10.8,
          'longitude': 106.7,
          'accuracyMeters': 5,
          'ttlMinutes': 15,
        }),
      );
      final locations = objects(await admin.request('GET', '/location-shares'));
      expect(locations.single['userId'], active['id']);
      expect(
        locationMapUri(locations.single).queryParameters['query'],
        '10.8,106.7',
      );
      await worker.request('DELETE', '/location-shares/${share['id']}');
      expect(await worker.request('GET', '/location-shares'), isEmpty);
      final image = faceImageBase64(await File(faceFile).readAsBytes());
      final enrollment = Json.from(
        await worker.request('POST', '/face/enroll', {
          'imageBase64': image,
          'enableQuickLogin': true,
        }),
      );
      final quick = Api(endpoint: endpoint);
      addTearDown(quick.client.close);
      final unlocked = Json.from(
        await quick.request('POST', '/auth/face-unlock', {
          'username': 'contract_worker',
          'deviceKey': enrollment['deviceKey'],
          'imageBase64': image,
        }),
      );
      expect(unlocked['challengeId'], isNull);
      quick.acceptTokens(unlocked);
      final updated = await quick.request('PATCH', '/me', {
        'phone': '0912345678',
        'bio': 'Contract profile update',
      });
      expect(updated['phone'], '0912345678');
      expect(
        (await worker.request('GET', '/me'))['bio'],
        'Contract profile update',
      );
      await worker.request('DELETE', '/face/enroll');
      await expectLater(
        quick.request('GET', '/me'),
        throwsA(isA<ApiException>()),
      );
      await worker.request('POST', '/face/enroll', {'imageBase64': image});
      expect((await worker.request('GET', '/face/status'))['enrolled'], isTrue);
      // Respect the real server's OTP cooldown, including after registration.
      await expectLater(
        worker.request('POST', '/auth/face-login', {
          'username': 'contract_worker',
          'imageBase64': image,
        }),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 429)),
      );
      await Future<void>.delayed(const Duration(seconds: 61));
      final faceChallenge = Json.from(
        await worker.request('POST', '/auth/face-login', {
          'username': 'contract_worker',
          'imageBase64': image,
        }),
      );
      expect(faceChallenge.containsKey('accessToken'), isFalse);
      await verify(worker, faceChallenge, 'worker@example.test');
      await worker.request('DELETE', '/face/enroll');
      await workerData.load();
      final rows = objects(workerData.report['rows']);
      expect(rows.single['source'], 'correction');
      expect(rows.single['recordedCheckInAt'], isNotNull);
      expect(reportCsv(workerData.report), contains('Contract Worker'));
      expect(workerData.month, DateFormat('yyyy-MM').format(DateTime.now()));
      final disposable = Json.from(
        await admin.request('POST', '/employees', {
          'fullName': 'Disposable Worker',
          'username': 'disposable_worker',
          'email': 'disposable@example.test',
          'password': 'Contract-test-password-29',
        }),
      );
      await admin.request('PATCH', '/employees/${disposable['id']}', {
        'fullName': 'Renamed Worker',
      });
      await admin.request('DELETE', '/employees/${disposable['id']}');
      final emptyBranch = Json.from(
        await admin.request('POST', '/branches', {
          'name': 'Disposable Office',
          'address': 'Contract empty branch',
          'latitude': 10,
          'longitude': 106,
          'radiusMeters': 100,
        }),
      );
      await admin.request('DELETE', '/branches/${emptyBranch['id']}');
      await expectLater(
        admin.request('DELETE', '/shifts/${shift['id']}'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 409)),
      );
      await worker.request('POST', '/auth/logout', {
        'refreshToken': worker.refreshToken,
      });
      worker.refreshToken = null;
      await expectLater(
        worker.request('GET', '/me'),
        throwsA(isA<ApiException>().having((e) => e.status, 'status', 401)),
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
