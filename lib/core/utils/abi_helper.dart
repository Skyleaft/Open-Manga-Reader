import 'abi_helper_stub.dart'
    if (dart.library.ffi) 'abi_helper_io.dart' as helper;

String getPlatformAbi() => helper.getPlatformAbi();
