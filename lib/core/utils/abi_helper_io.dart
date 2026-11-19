import 'dart:ffi';
import 'dart:io';

String getPlatformAbi() {
  if (!Platform.isAndroid) return '';
  try {
    final abiStr = Abi.current().toString().toLowerCase();
    if (abiStr.contains('arm64')) return 'arm64-v8a';
    if (abiStr.contains('arm')) return 'armeabi-v7a';
    if (abiStr.contains('x64') || abiStr.contains('x86_64')) return 'x86_64';
    if (abiStr.contains('ia32') || abiStr.contains('x86')) return 'x86';
    return '';
  } catch (_) {
    return '';
  }
}
