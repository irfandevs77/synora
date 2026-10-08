import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase_options.dart';

class SavedAccount {
  final String userId;
  final String username;
  final String displayName;
  final String email;

  const SavedAccount({
    required this.userId,
    required this.username,
    required this.displayName,
    required this.email,
  });

  factory SavedAccount.fromJson(Map<String, dynamic> json) => SavedAccount(
    userId: (json['userId'] ?? '').toString(),
    username: (json['username'] ?? '').toString(),
    displayName: (json['displayName'] ?? '').toString(),
    email: (json['email'] ?? '').toString(),
  );

  Map<String, String> toJson() => {
    'userId': userId,
    'username': username,
    'displayName': displayName,
    'email': email,
  };

  String get title => displayName.isNotEmpty
      ? displayName
      : username.isNotEmpty
      ? '@$username'
      : email.isNotEmpty
      ? email
      : 'Synora account';

  String get subtitle =>
      username.isNotEmpty && displayName.isNotEmpty ? '@$username' : email;
}

class SavedAccountsService {
  static const _storageKey = 'saved_synora_accounts';
  static const _refreshTokenKeyPrefix = 'saved_account_refresh_token_';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  Future<List<SavedAccount>> getAccounts() async {
    final preferences = await SharedPreferences.getInstance();
    final entries = preferences.getStringList(_storageKey) ?? const <String>[];
    final accounts = <SavedAccount>[];
    for (final entry in entries) {
      try {
        final account = SavedAccount.fromJson(
          Map<String, dynamic>.from(jsonDecode(entry) as Map),
        );
        if (account.userId.isNotEmpty) accounts.add(account);
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return accounts;
  }

  Future<void> rememberCurrentAccount({String? userId}) async {
    final authUser = FirebaseAuth.instance.currentUser;
    final id = userId ?? authUser?.uid ?? '';
    if (id.isEmpty) return;

    final profile = await FirebaseFirestore.instance
        .collection('users')
        .doc(id)
        .get();
    final data = profile.data() ?? const <String, dynamic>{};
    final account = SavedAccount(
      userId: id,
      username: (data['username'] ?? '').toString(),
      displayName: (data['name'] ?? '').toString(),
      email: authUser?.email ?? (data['email'] ?? '').toString(),
    );
    final accounts = await getAccounts();
    final updated = [account, ...accounts.where((saved) => saved.userId != id)];
    final preferences = await SharedPreferences.getInstance();
    await preferences.setStringList(
      _storageKey,
      updated.map((saved) => jsonEncode(saved.toJson())).toList(),
    );
  }

  Future<void> saveCurrentAccountSession({
    required String userId,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.https(
        'identitytoolkit.googleapis.com',
        '/v1/accounts:signInWithPassword',
        {'key': DefaultFirebaseOptions.currentPlatform.apiKey},
      ),
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
        'returnSecureToken': true,
      }),
    );
    final result = Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    if (response.statusCode != 200) {
      final error = Map<String, dynamic>.from(result['error'] as Map);
      throw StateError(
        'Could not save account session (${error['message'] ?? 'unknown error'}).',
      );
    }

    final returnedUserId = result['localId']?.toString();
    final refreshToken = result['refreshToken']?.toString();
    if (returnedUserId != userId ||
        refreshToken == null ||
        refreshToken.isEmpty) {
      throw StateError('Firebase returned an invalid saved account session.');
    }
    await _secureStorage.write(
      key: '$_refreshTokenKeyPrefix$userId',
      value: refreshToken,
    );
  }

  Future<String> switchToAccount(String userId) async {
    final refreshToken = await _secureStorage.read(
      key: '$_refreshTokenKeyPrefix$userId',
    );
    if (refreshToken == null || refreshToken.isEmpty) {
      throw const SavedAccountSessionExpiredException();
    }

    late final Map<String, dynamic> result;
    try {
      final callable = FirebaseFunctions.instance.httpsCallable(
        'switchSavedAccount',
      );
      final response = await callable.call({
        'refreshToken': refreshToken,
        'apiKey': DefaultFirebaseOptions.currentPlatform.apiKey,
      });
      result = Map<String, dynamic>.from(response.data as Map);
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'unauthenticated') {
        await _secureStorage.delete(key: '$_refreshTokenKeyPrefix$userId');
        throw const SavedAccountSessionExpiredException();
      }
      rethrow;
    }

    final returnedUserId = result['uid']?.toString();
    final customToken = result['customToken']?.toString();
    final updatedRefreshToken = result['refreshToken']?.toString();
    if (returnedUserId != userId ||
        customToken == null ||
        customToken.isEmpty ||
        updatedRefreshToken == null ||
        updatedRefreshToken.isEmpty) {
      throw StateError('Firebase returned an invalid saved account session.');
    }

    await _secureStorage.write(
      key: '$_refreshTokenKeyPrefix$userId',
      value: updatedRefreshToken,
    );
    final credential = await FirebaseAuth.instance.signInWithCustomToken(
      customToken,
    );
    if (credential.user?.uid != userId) {
      throw StateError('Firebase signed in to an unexpected account.');
    }

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString('userDocId', userId);
    return userId;
  }

  Future<void> clearSavedAccountSessions() async {
    final storedValues = await _secureStorage.readAll();
    final refreshTokenKeys = storedValues.keys.where(
      (key) => key.startsWith(_refreshTokenKeyPrefix),
    );
    await Future.wait(
      refreshTokenKeys.map((key) => _secureStorage.delete(key: key)),
    );
  }
}

class SavedAccountSessionExpiredException implements Exception {
  const SavedAccountSessionExpiredException();

  @override
  String toString() => 'This account needs to be signed in once again.';
}
