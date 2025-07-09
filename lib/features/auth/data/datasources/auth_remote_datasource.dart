import 'dart:convert';
import '../../../../core/api/api_client.dart';
import '../../domain/entities/auth_state.dart';
import '../models/user_model.dart';

abstract class AuthRemoteDataSource {
  Future<AuthState> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  Future<AuthState> login({
    required String email,
    required String password,
  });

  Future<AuthState> refreshToken(String refreshToken);

  Future<bool> verifyToken(String accessToken);
}

class AuthRemoteDataSourceImpl implements AuthRemoteDataSource {
  @override
  Future<AuthState> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    final requestBody = {
      'email': email,
      'password': password,
      'full_name': fullName,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    };

    final response = await ApiClient.post('/auth/register', requestBody);
    ApiClient.handleResponse(response);

    final responseData = json.decode(response.body);
    
    return _parseAuthResponse(responseData);
  }

  @override
  Future<AuthState> login({
    required String email,
    required String password,
  }) async {
    final requestBody = {
      'email': email,
      'password': password,
    };

    final response = await ApiClient.post('/auth/login', requestBody);
    ApiClient.handleResponse(response);

    final responseData = json.decode(response.body);
    
    return _parseAuthResponse(responseData);
  }

  @override
  Future<AuthState> refreshToken(String refreshToken) async {
    final requestBody = {
      'refresh_token': refreshToken,
    };

    final response = await ApiClient.post('/auth/refresh', requestBody);
    ApiClient.handleResponse(response);

    final responseData = json.decode(response.body);
    
    return _parseAuthResponse(responseData);
  }

  @override
  Future<bool> verifyToken(String accessToken) async {
    try {
      final response = await ApiClient.post('/auth/verify', {
        'access_token': accessToken,
      });

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        return responseData['valid'] == true;
      }
      
      return false;
    } catch (e) {
      return false;
    }
  }

  AuthState _parseAuthResponse(Map<String, dynamic> responseData) {
    final user = UserModel.fromMap(responseData);
    
    final accessToken = responseData['access_token'] as String;
    final refreshToken = responseData['refresh_token'] as String;
    final expiresIn = responseData['expires_in'] as int; // seconds
    
    final expiresAt = DateTime.now().add(Duration(seconds: expiresIn));

    return AuthState.authenticated(
      user: user,
      accessToken: accessToken,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
    );
  }
} 