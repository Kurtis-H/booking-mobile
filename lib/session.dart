import 'package:flutter/widgets.dart';

import 'api/booking_api.dart';

/// Who is signed in. The booking API identifies buyers by API key; the demo
/// keys are public test data.
class Session extends ChangeNotifier {
  Session(this.api);

  static const demoKey = 'key-user-1';

  final BookingApi api;
  String? _apiKey;

  String? get apiKey => _apiKey;
  bool get isSignedIn => _apiKey != null;

  /// Checks the key with a cheap authenticated call before accepting it.
  Future<void> signIn(String key) async {
    final trimmed = key.trim();
    if (trimmed.isEmpty) throw const SignInException('Enter an API key.');
    try {
      await api.listOrders(trimmed);
    } on ApiException catch (e) {
      if (e.statusCode == 401) throw const SignInException("That API key wasn't recognised.");
      throw const SignInException("We couldn't reach the booking service. Please try again.");
    }
    _apiKey = trimmed;
    notifyListeners();
  }

  void signOut() {
    _apiKey = null;
    notifyListeners();
  }
}

class SignInException implements Exception {
  const SignInException(this.message);
  final String message;
}

/// Makes the session (and its API client) available to every screen.
class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child})
      : super(notifier: session);

  static Session of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<SessionScope>();
    assert(scope != null, 'No SessionScope above this widget');
    return scope!.notifier!;
  }
}
