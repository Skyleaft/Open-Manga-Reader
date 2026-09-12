import 'package:flutter_test/flutter_test.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:my_manga_reader/core/services/network_status_service.dart';

class MockConnectivity implements Connectivity {
  final Stream<List<ConnectivityResult>> _stream;
  final List<ConnectivityResult> _initial;

  MockConnectivity({
    required Stream<List<ConnectivityResult>> stream,
    List<ConnectivityResult> initial = const [ConnectivityResult.wifi],
  })  : _stream = stream,
        _initial = initial;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _stream;

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => _initial;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('NetworkStatusService Tests', () {
    test('reportNetworkError and reportNetworkSuccess update isOnlineNotifier', () {
      final service = NetworkStatusService(
        connectivity: MockConnectivity(stream: const Stream.empty()),
      );

      expect(service.isOnline, isTrue);

      service.reportNetworkError();
      expect(service.isOnline, isFalse);

      service.reportNetworkSuccess();
      expect(service.isOnline, isTrue);

      service.dispose();
    });

    test('onStatusChange emits boolean values on status change', () async {
      final service = NetworkStatusService(
        connectivity: MockConnectivity(stream: const Stream.empty()),
      );

      final transitions = <bool>[];
      service.onStatusChange.listen((status) => transitions.add(status));

      service.reportNetworkError();
      service.reportNetworkSuccess();
      service.reportNetworkError();

      await Future.delayed(const Duration(milliseconds: 20));

      expect(transitions, [false, true, false]);
      service.dispose();
    });
  });
}
