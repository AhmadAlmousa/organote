import 'file_store.dart';
import 'file_store_stub.dart'
    if (dart.library.io) 'file_store_io.dart'
    if (dart.library.js_interop) 'file_store_web.dart'
    as platform;

FileStore createPlatformFileStore() => platform.createFileStore();
