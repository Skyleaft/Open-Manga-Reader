import 'dart:async';
import 'package:material_ui/material_ui.dart';
import 'package:battery_plus/battery_plus.dart';
import 'package:intl/intl.dart';

class ReaderStatusBarInfo extends StatefulWidget {
  const ReaderStatusBarInfo({super.key});

  @override
  State<ReaderStatusBarInfo> createState() => _ReaderStatusBarInfoState();
}

class _ReaderStatusBarInfoState extends State<ReaderStatusBarInfo> {
  final Battery _battery = Battery();
  int _batteryLevel = 100;
  BatteryState _batteryState = BatteryState.unknown;
  StreamSubscription<BatteryState>? _batterySubscription;
  Timer? _timeTimer;
  String _currentTime = '';

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timeTimer = Timer.periodic(const Duration(seconds: 30), (_) => _updateTime());
    _initBattery();
  }

  void _updateTime() {
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('HH:mm').format(DateTime.now());
      });
    }
  }

  Future<void> _initBattery() async {
    try {
      final level = await _battery.batteryLevel;
      if (mounted) {
        setState(() {
          _batteryLevel = level;
        });
      }
      _batterySubscription = _battery.onBatteryStateChanged.listen((state) async {
        final level = await _battery.batteryLevel;
        if (mounted) {
          setState(() {
            _batteryState = state;
            _batteryLevel = level;
          });
        }
      });
    } catch (_) {
      // Platform may not support battery querying (e.g. desktop/web without sensors)
    }
  }

  @override
  void dispose() {
    _timeTimer?.cancel();
    _batterySubscription?.cancel();
    super.dispose();
  }

  IconData _getBatteryIcon() {
    if (_batteryState == BatteryState.charging) {
      return Icons.battery_charging_full_rounded;
    }
    if (_batteryLevel <= 15) {
      return Icons.battery_alert_rounded;
    } else if (_batteryLevel <= 30) {
      return Icons.battery_3_bar_rounded;
    } else if (_batteryLevel <= 60) {
      return Icons.battery_4_bar_rounded;
    } else if (_batteryLevel <= 85) {
      return Icons.battery_5_bar_rounded;
    }
    return Icons.battery_full_rounded;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBatteryIcon(),
            color: _batteryLevel <= 15 ? Colors.redAccent : Colors.white70,
            size: 14,
          ),
          const SizedBox(width: 4),
          Text(
            '$_batteryLevel%',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 3,
            height: 3,
            decoration: const BoxDecoration(
              color: Colors.white38,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _currentTime,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
