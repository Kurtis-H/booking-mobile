import 'package:flutter/material.dart';

import 'api/booking_api.dart';
import 'app.dart';
import 'session.dart';

void main() {
  final api = BookingApi(baseUrl: BookingApi.defaultBaseUrl);
  runApp(BookingApp(session: Session(api)));
}
