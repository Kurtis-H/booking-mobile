import '../api/booking_api.dart';

/// Turn an order failure into something a buyer can act on.
String orderErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isOffline) return "You're offline. Check your connection and try again.";
    if (error.statusCode == 409) return conflictMessage(error);
    switch (error.statusCode) {
      case 404:
        return 'One of those seats no longer exists. The seat map has been refreshed.';
      case 401:
        return 'Your session has ended. Please sign in again.';
      case 429:
        final wait = error.retryAfterSeconds;
        return wait != null
            ? 'Too many requests. Please wait $wait seconds and try again.'
            : 'Too many requests. Please wait a moment and try again.';
    }
  }
  return 'Something went wrong placing your order. Please try again.';
}

/// Message for a screen that failed to load.
String loadErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isOffline) return "You're offline. Check your connection and try again.";
    if (error.statusCode == 404) return "We couldn't find that.";
  }
  return "We couldn't load this right now. Please try again.";
}

/// The API answers 409 for three reasons, and each needs its own words:
/// telling someone at the buyer limit that "someone took their seat" sends
/// them hunting for seats they can never buy.
String conflictMessage(ApiException error) {
  if (error.message.contains('held by another buyer')) {
    return 'Someone is holding one of those seats right now. The seat map has been refreshed, so please pick again.';
  }
  final limit = RegExp(r'at most (\d+) seats').firstMatch(error.message);
  if (limit != null) {
    return "You can have at most ${limit.group(1)} seats for one event, counting seats you've already bought and seats you're holding.";
  }
  return 'Someone just took one of those seats. The seat map has been refreshed, so please pick again.';
}

/// What went wrong placing or changing a hold.
String holdErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isOffline) return "You're offline. Check your connection and try again.";
    if (error.statusCode == 409) return conflictMessage(error);
    if (error.statusCode == 401) return 'Your session has ended. Please sign in again.';
  }
  return "We couldn't hold those seats. Please try again.";
}
