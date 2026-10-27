import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_failure.dart';
import '../network/dio_client.dart';
import '../storage/secure_storage.dart';
import 'app_lock_service.dart';
import 'token_manager.dart';

/// Where the app is in its lifecycle; the router redirects on this.
enum SessionPhase { loading, needsActivation, pendingApproval, needsPinSetup, locked, needsConsent, ready }

class Me {
  const Me({required this.employee, required this.company, required this.features, required this.consentRequired, this.notice});

  final Map<String, dynamic> employee;
  final Map<String, dynamic> company;
  final Map<String, dynamic> features;
  final bool consentRequired;
  final Map<String, dynamic>? notice;

  bool has(String feature) => features[feature] == true;
  String get fullName => employee['fullName'] as String? ?? '';
  String get companyName => company['name'] as String? ?? '';

  static Me fromJson(Map<String, dynamic> json) {
    final consent = json['consent'] as Map<String, dynamic>? ?? const {};
    return Me(
      employee: json['employee'] as Map<String, dynamic>? ?? const {},
      company: json['company'] as Map<String, dynamic>? ?? const {},
      features: json['features'] as Map<String, dynamic>? ?? const {},
      consentRequired: consent['required'] == true,
      notice: consent['notice'] as Map<String, dynamic>?,
    );
  }
}

class SessionState {
  const SessionState({required this.phase, this.me, this.pendingBindingId, this.message});

  final SessionPhase phase;
  final Me? me;
  final String? pendingBindingId;
  final String? message;

  SessionState copyWith({SessionPhase? phase, Me? me, String? pendingBindingId, String? message}) =>
      SessionState(phase: phase ?? this.phase, me: me ?? this.me, pendingBindingId: pendingBindingId ?? this.pendingBindingId, message: message);
}

class SessionController extends StateNotifier<SessionState> {
  SessionController({required this.store, required this.tokens, required this.lock, required this.api})
      : super(const SessionState(phase: SessionPhase.loading)) {
    bootstrap();
  }

  final SecureStore store;
  final TokenManager tokens;
  final AppLockService lock;
  final ApiClient Function() api;

  Future<void> bootstrap() async {
    final pending = await store.read(SecureKeys.pendingBindingId);
    if (pending != null) {
      state = SessionState(phase: SessionPhase.pendingApproval, pendingBindingId: pending);
      return;
    }
    if (!await tokens.hasSession()) {
      state = const SessionState(phase: SessionPhase.needsActivation);
      return;
    }
    state = SessionState(phase: await lock.hasPin() ? SessionPhase.locked : SessionPhase.needsPinSetup);
  }

  /// After activation or approval: tokens are stored, PIN comes next.
  Future<void> activated() async {
    await store.delete(SecureKeys.pendingBindingId);
    state = SessionState(phase: await lock.hasPin() ? SessionPhase.locked : SessionPhase.needsPinSetup);
  }

  Future<void> awaitingApproval(String bindingId) async {
    await store.write(SecureKeys.pendingBindingId, bindingId);
    state = SessionState(phase: SessionPhase.pendingApproval, pendingBindingId: bindingId);
  }

  Future<void> pinSet() => unlocked();

  /// Called after a successful PIN/biometric check: loads the profile and decides on consent.
  Future<void> unlocked() async {
    try {
      final me = Me.fromJson(await api().get<Map<String, dynamic>>('/v1/mobile/me'));
      state = SessionState(phase: me.consentRequired ? SessionPhase.needsConsent : SessionPhase.ready, me: me);
    } on ApiFailure catch (e) {
      if (e.isNetwork) {
        state = SessionState(phase: SessionPhase.ready, me: state.me, message: e.message);
      } else if (e.isAuth) {
        await sessionLost();
      } else {
        state = state.copyWith(message: e.message);
      }
    }
  }

  Future<void> refreshMe() async {
    try {
      final me = Me.fromJson(await api().get<Map<String, dynamic>>('/v1/mobile/me'));
      state = SessionState(phase: me.consentRequired ? SessionPhase.needsConsent : SessionPhase.ready, me: me);
    } on ApiFailure catch (e) {
      if (e.isAuth) await sessionLost();
    }
  }

  void relock() {
    if (state.phase == SessionPhase.ready || state.phase == SessionPhase.needsConsent) {
      state = SessionState(phase: SessionPhase.locked, me: state.me);
    }
  }

  /// Device released, employee deactivated or key lost: back to activation.
  Future<void> sessionLost() async {
    await tokens.clear();
    await lock.clearPin();
    await store.clearSession();
    state = const SessionState(phase: SessionPhase.needsActivation, message: 'This phone is no longer registered. Ask your employer for a new activation code.');
  }
}
