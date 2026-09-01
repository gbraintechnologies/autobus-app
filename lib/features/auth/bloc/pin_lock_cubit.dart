import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:autobus/features/auth/services/pin_lock_service.dart';

enum PinLockStatus { unknown, disabled, unlocked, locked }

class PinLockState extends Equatable {
  const PinLockState({
    this.status = PinLockStatus.unknown,
    this.busy = false,
    this.error,
  });

  final PinLockStatus status;
  final bool busy;
  final String? error;

  bool get isLocked => status == PinLockStatus.locked;
  bool get isEnabled =>
      status == PinLockStatus.locked || status == PinLockStatus.unlocked;

  PinLockState copyWith({
    PinLockStatus? status,
    bool? busy,
    String? error,
    bool clearError = false,
  }) {
    return PinLockState(
      status: status ?? this.status,
      busy: busy ?? this.busy,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [status, busy, error];
}

class PinLockCubit extends Cubit<PinLockState> {
  PinLockCubit({required this.service}) : super(const PinLockState());

  final PinLockService service;
  String? _userKey;

  String? get userKey => _userKey;

  Future<void> bindUser(String userKey, {required bool freshLogin}) async {
    final alreadyBound =
        _userKey == userKey && state.status != PinLockStatus.unknown;
    _userKey = userKey;
    if (freshLogin) {
      final enabled = await service.isEnabled(userKey);
      if (enabled) await service.markActive(userKey);
      emit(
        PinLockState(
          status: enabled ? PinLockStatus.unlocked : PinLockStatus.disabled,
        ),
      );
      return;
    }
    if (alreadyBound) return;
    await evaluate();
  }

  Future<void> onPaused() async {
    final key = _userKey;
    if (key == null) return;
    if (state.status == PinLockStatus.unlocked) {
      await service.markActive(key);
    }
  }

  Future<void> onResumed() async {
    if (state.status != PinLockStatus.unlocked) return;
    await evaluate();
  }

  Future<void> evaluate() async {
    final key = _userKey;
    if (key == null) {
      emit(const PinLockState(status: PinLockStatus.disabled));
      return;
    }
    try {
      final enabled = await service.isEnabled(key);
      if (!enabled) {
        emit(const PinLockState(status: PinLockStatus.disabled));
        return;
      }
      final lock = await service.shouldLock(key);
      emit(
        PinLockState(
          status: lock ? PinLockStatus.locked : PinLockStatus.unlocked,
        ),
      );
    } catch (_) {
      emit(const PinLockState(status: PinLockStatus.locked));
    }
  }

  Future<bool> unlock(String pin) async {
    final key = _userKey;
    if (key == null) return false;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      final ok = await service.verify(key, pin);
      if (!ok) {
        emit(
          state.copyWith(
            busy: false,
            status: PinLockStatus.locked,
            error: 'Incorrect PIN',
          ),
        );
        return false;
      }
      await service.markActive(key);
      emit(const PinLockState(status: PinLockStatus.unlocked));
      return true;
    } catch (_) {
      emit(
        state.copyWith(
          busy: false,
          status: PinLockStatus.locked,
          error: 'Could not verify PIN',
        ),
      );
      return false;
    }
  }

  Future<bool> enable(String pin) async {
    final key = _userKey;
    if (key == null) return false;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await service.enable(key, pin);
      emit(const PinLockState(status: PinLockStatus.unlocked));
      return true;
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Could not enable PIN'));
      return false;
    }
  }

  Future<bool> changePin(String current, String next) async {
    final key = _userKey;
    if (key == null) return false;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await service.changePin(key, current, next);
      emit(const PinLockState(status: PinLockStatus.unlocked));
      return true;
    } on StateError {
      emit(state.copyWith(busy: false, error: 'Incorrect PIN'));
      return false;
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Could not change PIN'));
      return false;
    }
  }

  Future<bool> disable(String pin) async {
    final key = _userKey;
    if (key == null) return false;
    emit(state.copyWith(busy: true, clearError: true));
    try {
      await service.disable(key, pin);
      emit(const PinLockState(status: PinLockStatus.disabled));
      return true;
    } on StateError {
      emit(
        state.copyWith(
          busy: false,
          status: PinLockStatus.unlocked,
          error: 'Incorrect PIN',
        ),
      );
      return false;
    } catch (_) {
      emit(state.copyWith(busy: false, error: 'Could not disable PIN'));
      return false;
    }
  }

  void clearError() {
    if (state.error != null) emit(state.copyWith(clearError: true));
  }

  void reset() {
    _userKey = null;
    emit(const PinLockState());
  }
}
