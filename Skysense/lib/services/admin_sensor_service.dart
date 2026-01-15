import 'package:flutter_application_skysense/services/auth_service.dart';

class AdminSensorService {
  final AuthService _auth = AuthService();

  Future<List<Map<String, dynamic>>> fetchAvgDaily() async {
    return _auth.fetchAvgData();
  }
}
