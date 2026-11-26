import '../api/booking_api.dart';

/// Turn an order failure into something a buyer can act on.
String orderErrorMessage(Object error) {
  if (error is ApiException) {
    if (error.isOffline) return "You're offline. Check your connection and try again.";
    switch (error.statusCode) {
      case 409:
        return 'Someone just took one of those seats. The seat map has been refreshed, so please pick again.';
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
