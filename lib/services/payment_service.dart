import 'dart:convert';
import 'package:http/http.dart' as http;

class PaymentService {
  // Fapshi API Configuration - Sandbox
  static const String _apiBaseUrl = 'https://sandbox.fapshi.com';
  
  // Your credentials from the screenshot
  static const String _apiKey = 'FAK_7655892791e2df8104620ee4ad0268b5';
  static const String _apiUser = '1489f508-df8f-4d59-934b-f34fe1ed4220';
  
  // Set to true for testing without real API
  static const bool useMockMode = false;
  
  static Future<Map<String, dynamic>> initializePayment({
    required double amount,
    required String phone,
    required String provider,
    required String orderId,
    required String orderNumber,
    required String email,
    required String userId,
    required String redirectUrl,
  }) async {
    // Mock mode for testing
    if (useMockMode) {
      print('🔵 Using MOCK payment service');
      await Future.delayed(const Duration(seconds: 2));
      return {
        'status': 'success',
        'transaction_id': 'MOCK_${DateTime.now().millisecondsSinceEpoch}',
        'payment_url': '',
        'message': 'Mock payment successful',
      };
    }
    
    try {
      print('📤 Sending payment request to Fapshi API...');
      print('📍 URL: $_apiBaseUrl/initiate-pay');
      print('🔑 Using API Key: ${_apiKey.substring(0, 10)}...');
      
      // Based on the curl command format
      final requestBody = {
        'amount': amount,
        'email': email,
        'phone': phone,
        'provider': provider,
        'redirectUrl': redirectUrl,
        'userId': userId,
        'externalId': orderId,
        'message': 'Payment for order #$orderNumber',
      };
      
      print('📦 Request body: ${jsonEncode(requestBody)}');
      
      // Try all possible header combinations
      
      // Option 1: curl format (apikey and apiuser as separate headers)
      print('🔄 Trying curl format...');
      var response = await http.post(
        Uri.parse('$_apiBaseUrl/initiate-pay'),
        headers: {
          'apikey': _apiKey,
          'apiuser': _apiUser, // Using the UUID from screenshot
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('📥 Response status: ${response.statusCode}');
      print('📥 Response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {
          'status': 'success',
          'transaction_id': data['transactionId'] ?? data['id'] ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
          'payment_url': data['paymentUrl'] ?? data['redirectUrl'] ?? '',
          'message': data['message'] ?? 'Payment initiated successfully',
        };
      }
      
      // Option 2: Try with X-API-Key header
      print('🔄 Trying X-API-Key format...');
      response = await http.post(
        Uri.parse('$_apiBaseUrl/initiate-pay'),
        headers: {
          'X-API-Key': _apiKey,
          'X-API-User': _apiUser,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('📥 X-API-Key response status: ${response.statusCode}');
      print('📥 X-API-Key response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {
          'status': 'success',
          'transaction_id': data['transactionId'] ?? data['id'] ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
          'payment_url': data['paymentUrl'] ?? data['redirectUrl'] ?? '',
          'message': data['message'] ?? 'Payment initiated successfully',
        };
      }
      
      // Option 3: Try Bearer token
      print('🔄 Trying Bearer token format...');
      response = await http.post(
        Uri.parse('$_apiBaseUrl/initiate-pay'),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('📥 Bearer response status: ${response.statusCode}');
      print('📥 Bearer response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {
          'status': 'success',
          'transaction_id': data['transactionId'] ?? data['id'] ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
          'payment_url': data['paymentUrl'] ?? data['redirectUrl'] ?? '',
          'message': data['message'] ?? 'Payment initiated successfully',
        };
      }
      
      // Option 4: Try with just apikey and no apiuser
      print('🔄 Trying just apikey...');
      response = await http.post(
        Uri.parse('$_apiBaseUrl/initiate-pay'),
        headers: {
          'apikey': _apiKey,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      );
      
      print('📥 Just apikey response status: ${response.statusCode}');
      print('📥 Just apikey response body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        return {
          'status': 'success',
          'transaction_id': data['transactionId'] ?? data['id'] ?? 'TXN_${DateTime.now().millisecondsSinceEpoch}',
          'payment_url': data['paymentUrl'] ?? data['redirectUrl'] ?? '',
          'message': data['message'] ?? 'Payment initiated successfully',
        };
      }
      
      // All options failed
      return {
        'status': 'error',
        'message': 'Payment failed: All authentication methods failed. Please check your credentials with Fapshi support.',
      };
    } catch (e) {
      print('❌ Payment error: $e');
      return {
        'status': 'error',
        'message': 'Error: ${e.toString()}',
      };
    }
  }

  static Future<Map<String, dynamic>> verifyPayment(String transactionId) async {
    if (useMockMode) {
      return {
        'status': 'success',
        'verified': true,
        'transaction_id': transactionId,
        'message': 'Mock payment verified',
      };
    }
    
    try {
      final response = await http.get(
        Uri.parse('$_apiBaseUrl/verify-pay/$transactionId'),
        headers: {
          'apikey': _apiKey,
          'apiuser': _apiUser,
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'status': 'success',
          'verified': data['status'] == 'completed' || data['verified'] == true,
          'transaction_id': transactionId,
          'message': data['message'] ?? 'Payment verified',
        };
      } else {
        return {
          'status': 'error',
          'message': 'Payment verification failed: ${response.body}',
        };
      }
    } catch (e) {
      return {
        'status': 'error',
        'message': 'Error: ${e.toString()}',
      };
    }
  }
}