import 'dart:ffi';
import 'dart:io';

// FFI type definitions
typedef CreateJobForProcessNative = IntPtr Function(Uint32 processId);
typedef CreateJobForProcessDart = int Function(int processId);

typedef TerminateJobNative = Bool Function(IntPtr jobHandle);
typedef TerminateJobDart = bool Function(int jobHandle);

class NativeBindings {
  static NativeBindings? _instance;
  static NativeBindings get instance => _instance ??= NativeBindings._();

  late final DynamicLibrary _lib;
  late final CreateJobForProcessDart _createJobForProcess;
  late final TerminateJobDart _terminateJob;

  bool _loaded = false;

  NativeBindings._() {
    _loadLibrary();
  }

  void _loadLibrary() {
    if (_loaded) return;

    try {
      // Try to load from the executable directory first (release build)
      final exeDir = File(Platform.resolvedExecutable).parent.path;
      final releasePath = '$exeDir\\marcha_native.dll';

      if (File(releasePath).existsSync()) {
        _lib = DynamicLibrary.open(releasePath);
      } else {
        // Fallback to project root (dev build)
        _lib = DynamicLibrary.open('marcha_native.dll');
      }

      _createJobForProcess = _lib
          .lookupFunction<CreateJobForProcessNative, CreateJobForProcessDart>(
              'create_job_for_process');

      _terminateJob =
          _lib.lookupFunction<TerminateJobNative, TerminateJobDart>(
              'terminate_job');

      _loaded = true;
    } catch (e) {
      // DLL not available - functions will return safe defaults
      _loaded = false;
    }
  }

  /// Create a job object and assign a process to it.
  /// Returns job handle (0 on failure or if DLL not loaded).
  int createJobForProcess(int pid) {
    if (!_loaded) return 0;
    return _createJobForProcess(pid);
  }

  /// Terminate all processes in the job and close the handle.
  /// Returns false if DLL not loaded or termination failed.
  bool terminateJob(int jobHandle) {
    if (!_loaded || jobHandle == 0) return false;
    return _terminateJob(jobHandle);
  }

  /// Check if native bindings are available.
  bool get isAvailable => _loaded;
}
