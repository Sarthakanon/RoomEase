import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:room_ease/features/auth/controllers/auth_controller.dart';
import 'package:room_ease/services/firebase_auth_service.dart';
import 'package:room_ease/services/api_service.dart';
import 'package:room_ease/models/user_model.dart';

// Generate mocks
@GenerateMocks([
  FirebaseAuthService,
  ApiService,
  User,
  UserCredential,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
])
import 'auth_controller_test.mocks.dart';

void main() {
  group('AuthController', () {
    late AuthController authController;
    late MockFirebaseAuthService mockFirebaseAuthService;
    late MockApiService mockApiService;
    late MockUser mockUser;
    late MockUserCredential mockUserCredential;
    late MockGoogleSignInAccount mockGoogleSignInAccount;
    late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;

    setUp(() {
      mockFirebaseAuthService = MockFirebaseAuthService();
      mockApiService = MockApiService();
      mockUser = MockUser();
      mockUserCredential = MockUserCredential();
      mockGoogleSignInAccount = MockGoogleSignInAccount();
      mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
      
      authController = AuthController(
        firebaseAuthService: mockFirebaseAuthService,
        apiService: mockApiService,
      );
    });

    group('loginWithEmail', () {
      test('should login successfully with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const idToken = 'mock-id-token';
        
        when(mockUser.uid).thenReturn('test-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.displayName).thenReturn('Test User');
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUser.getIdToken()).thenAnswer((_) async => idToken);
        
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuthService.signInWithEmailAndPassword(email, password))
            .thenAnswer((_) async => mockUserCredential);
        
        when(mockApiService.login(idToken))
            .thenAnswer((_) async => {
              'user_id': 'test-uid-123',
              'email': email,
              'session_id': 'session-123'
            });

        // Act
        final result = await authController.loginWithEmail(email, password);

        // Assert
        expect(result.isSuccess, true);
        expect(authController.isLoggedIn, true);
        expect(authController.currentUser?.uid, 'test-uid-123');
        expect(authController.currentUser?.email, email);
        
        verify(mockFirebaseAuthService.signInWithEmailAndPassword(email, password)).called(1);
        verify(mockApiService.login(idToken)).called(1);
      });

      test('should fail with unverified email', () async {
        // Arrange
        const email = 'unverified@example.com';
        const password = 'password123';
        
        when(mockUser.uid).thenReturn('unverified-uid');
        when(mockUser.email).thenReturn(email);
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuthService.signInWithEmailAndPassword(email, password))
            .thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await authController.loginWithEmail(email, password);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Please verify your email'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithEmailAndPassword(email, password)).called(1);
        verifyNever(mockApiService.login(any));
      });

      test('should fail with invalid credentials', () async {
        // Arrange
        const email = 'invalid@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuthService.signInWithEmailAndPassword(email, password))
            .thenThrow(FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found for that email.',
            ));

        // Act
        final result = await authController.loginWithEmail(email, password);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('No user found'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithEmailAndPassword(email, password)).called(1);
        verifyNever(mockApiService.login(any));
      });

      test('should fail with wrong password', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuthService.signInWithEmailAndPassword(email, password))
            .thenThrow(FirebaseAuthException(
              code: 'wrong-password',
              message: 'Wrong password provided.',
            ));

        // Act
        final result = await authController.loginWithEmail(email, password);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Wrong password'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithEmailAndPassword(email, password)).called(1);
        verifyNever(mockApiService.login(any));
      });

      test('should fail when API login fails', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        const idToken = 'mock-id-token';
        
        when(mockUser.uid).thenReturn('test-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.displayName).thenReturn('Test User');
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUser.getIdToken()).thenAnswer((_) async => idToken);
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuthService.signInWithEmailAndPassword(email, password))
            .thenAnswer((_) async => mockUserCredential);
        
        when(mockApiService.login(idToken))
            .thenThrow(Exception('API login failed'));

        // Act
        final result = await authController.loginWithEmail(email, password);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('API login failed'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithEmailAndPassword(email, password)).called(1);
        verify(mockApiService.login(idToken)).called(1);
      });
    });

    group('loginWithGoogle', () {
      test('should login successfully with Google', () async {
        // Arrange
        const idToken = 'google-id-token';
        const accessToken = 'google-access-token';
        const email = 'google@example.com';
        
        when(mockGoogleSignInAuthentication.idToken).thenReturn(idToken);
        when(mockGoogleSignInAuthentication.accessToken).thenReturn(accessToken);
        when(mockGoogleSignInAccount.authentication)
            .thenAnswer((_) async => mockGoogleSignInAuthentication);
        
        when(mockUser.uid).thenReturn('google-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.displayName).thenReturn('Google User');
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUser.getIdToken()).thenAnswer((_) async => 'firebase-id-token');
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuthService.signInWithGoogle())
            .thenAnswer((_) async => mockUserCredential);
        
        when(mockApiService.login('firebase-id-token'))
            .thenAnswer((_) async => {
              'user_id': 'google-uid-123',
              'email': email,
              'session_id': 'google-session-123'
            });

        // Act
        final result = await authController.loginWithGoogle();

        // Assert
        expect(result.isSuccess, true);
        expect(authController.isLoggedIn, true);
        expect(authController.currentUser?.uid, 'google-uid-123');
        expect(authController.currentUser?.email, email);
        
        verify(mockFirebaseAuthService.signInWithGoogle()).called(1);
        verify(mockApiService.login('firebase-id-token')).called(1);
      });

      test('should fail when Google sign-in is cancelled', () async {
        // Arrange
        when(mockFirebaseAuthService.signInWithGoogle())
            .thenAnswer((_) async => null);

        // Act
        final result = await authController.loginWithGoogle();

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Google sign-in was cancelled'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithGoogle()).called(1);
        verifyNever(mockApiService.login(any));
      });

      test('should fail when Google sign-in throws exception', () async {
        // Arrange
        when(mockFirebaseAuthService.signInWithGoogle())
            .thenThrow(Exception('Google sign-in failed'));

        // Act
        final result = await authController.loginWithGoogle();

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Google sign-in failed'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.signInWithGoogle()).called(1);
        verifyNever(mockApiService.login(any));
      });
    });

    group('signUpWithEmail', () {
      test('should sign up successfully', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'password123';
        const name = 'New User';
        
        when(mockUser.uid).thenReturn('new-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.displayName).thenReturn(name);
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUser.sendEmailVerification()).thenAnswer((_) async {});
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password))
            .thenAnswer((_) async => mockUserCredential);
        
        when(mockFirebaseAuthService.updateDisplayName(name))
            .thenAnswer((_) async {});

        // Act
        final result = await authController.signUpWithEmail(email, password, name);

        // Assert
        expect(result.isSuccess, true);
        expect(authController.isLoggedIn, false); // Should not be logged in until email is verified
        
        verify(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password)).called(1);
        verify(mockFirebaseAuthService.updateDisplayName(name)).called(1);
        verify(mockUser.sendEmailVerification()).called(1);
      });

      test('should fail with weak password', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = '123';
        const name = 'New User';
        
        when(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password))
            .thenThrow(FirebaseAuthException(
              code: 'weak-password',
              message: 'The password provided is too weak.',
            ));

        // Act
        final result = await authController.signUpWithEmail(email, password, name);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('password provided is too weak'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password)).called(1);
        verifyNever(mockFirebaseAuthService.updateDisplayName(any));
      });

      test('should fail with email already in use', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';
        const name = 'Existing User';
        
        when(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password))
            .thenThrow(FirebaseAuthException(
              code: 'email-already-in-use',
              message: 'The account already exists for that email.',
            ));

        // Act
        final result = await authController.signUpWithEmail(email, password, name);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('account already exists'));
        expect(authController.isLoggedIn, false);
        
        verify(mockFirebaseAuthService.createUserWithEmailAndPassword(email, password)).called(1);
        verifyNever(mockFirebaseAuthService.updateDisplayName(any));
      });
    });

    group('logout', () {
      test('should logout successfully', () async {
        // Arrange
        // Set up logged in state
        authController.setUser(UserModel(
          uid: 'test-uid',
          email: 'test@example.com',
          name: 'Test User',
        ));
        
        when(mockApiService.logout()).thenAnswer((_) async {});
        when(mockFirebaseAuthService.signOut()).thenAnswer((_) async {});

        // Act
        final result = await authController.logout();

        // Assert
        expect(result.isSuccess, true);
        expect(authController.isLoggedIn, false);
        expect(authController.currentUser, null);
        
        verify(mockApiService.logout()).called(1);
        verify(mockFirebaseAuthService.signOut()).called(1);
      });

      test('should handle API logout failure gracefully', () async {
        // Arrange
        authController.setUser(UserModel(
          uid: 'test-uid',
          email: 'test@example.com',
          name: 'Test User',
        ));
        
        when(mockApiService.logout()).thenThrow(Exception('API logout failed'));
        when(mockFirebaseAuthService.signOut()).thenAnswer((_) async {});

        // Act
        final result = await authController.logout();

        // Assert
        expect(result.isSuccess, true); // Should still succeed locally
        expect(authController.isLoggedIn, false);
        expect(authController.currentUser, null);
        
        verify(mockApiService.logout()).called(1);
        verify(mockFirebaseAuthService.signOut()).called(1);
      });

      test('should handle Firebase logout failure', () async {
        // Arrange
        authController.setUser(UserModel(
          uid: 'test-uid',
          email: 'test@example.com',
          name: 'Test User',
        ));
        
        when(mockApiService.logout()).thenAnswer((_) async {});
        when(mockFirebaseAuthService.signOut()).thenThrow(Exception('Firebase logout failed'));

        // Act
        final result = await authController.logout();

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Firebase logout failed'));
        
        verify(mockApiService.logout()).called(1);
        verify(mockFirebaseAuthService.signOut()).called(1);
      });
    });

    group('resetPassword', () {
      test('should send password reset email successfully', () async {
        // Arrange
        const email = 'reset@example.com';
        
        when(mockFirebaseAuthService.sendPasswordResetEmail(email))
            .thenAnswer((_) async {});

        // Act
        final result = await authController.resetPassword(email);

        // Assert
        expect(result.isSuccess, true);
        
        verify(mockFirebaseAuthService.sendPasswordResetEmail(email)).called(1);
      });

      test('should fail with invalid email', () async {
        // Arrange
        const email = 'invalid@example.com';
        
        when(mockFirebaseAuthService.sendPasswordResetEmail(email))
            .thenThrow(FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found for that email.',
            ));

        // Act
        final result = await authController.resetPassword(email);

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('No user found'));
        
        verify(mockFirebaseAuthService.sendPasswordResetEmail(email)).called(1);
      });
    });

    group('checkAuthState', () {
      test('should return true for valid session', () async {
        // Arrange
        when(mockApiService.verifySession())
            .thenAnswer((_) async => {
              'valid': true,
              'user_id': 'test-uid',
              'email': 'test@example.com'
            });

        // Act
        final isValid = await authController.checkAuthState();

        // Assert
        expect(isValid, true);
        expect(authController.isLoggedIn, true);
        
        verify(mockApiService.verifySession()).called(1);
      });

      test('should return false for invalid session', () async {
        // Arrange
        when(mockApiService.verifySession())
            .thenAnswer((_) async => {
              'valid': false,
              'message': 'Session expired'
            });

        // Act
        final isValid = await authController.checkAuthState();

        // Assert
        expect(isValid, false);
        expect(authController.isLoggedIn, false);
        
        verify(mockApiService.verifySession()).called(1);
      });

      test('should handle API error gracefully', () async {
        // Arrange
        when(mockApiService.verifySession())
            .thenThrow(Exception('Network error'));

        // Act
        final isValid = await authController.checkAuthState();

        // Assert
        expect(isValid, false);
        expect(authController.isLoggedIn, false);
        
        verify(mockApiService.verifySession()).called(1);
      });
    });

    group('refreshSession', () {
      test('should refresh session successfully', () async {
        // Arrange
        when(mockApiService.refreshSession())
            .thenAnswer((_) async => {
              'message': 'Session refreshed successfully',
              'expires_at': DateTime.now().add(Duration(hours: 24)).toIso8601String()
            });

        // Act
        final result = await authController.refreshSession();

        // Assert
        expect(result.isSuccess, true);
        
        verify(mockApiService.refreshSession()).called(1);
      });

      test('should fail to refresh expired session', () async {
        // Arrange
        when(mockApiService.refreshSession())
            .thenThrow(Exception('Session cannot be refreshed'));

        // Act
        final result = await authController.refreshSession();

        // Assert
        expect(result.isSuccess, false);
        expect(result.error, contains('Session cannot be refreshed'));
        
        verify(mockApiService.refreshSession()).called(1);
      });
    });

    group('validation', () {
      test('should validate email correctly', () {
        expect(authController.isValidEmail('test@example.com'), true);
        expect(authController.isValidEmail('invalid-email'), false);
        expect(authController.isValidEmail(''), false);
        expect(authController.isValidEmail('test@'), false);
        expect(authController.isValidEmail('@example.com'), false);
      });

      test('should validate password correctly', () {
        expect(authController.isValidPassword('password123'), true);
        expect(authController.isValidPassword('Pass123!'), true);
        expect(authController.isValidPassword('123'), false); // Too short
        expect(authController.isValidPassword(''), false); // Empty
        expect(authController.isValidPassword('pass'), false); // Too short
      });

      test('should validate name correctly', () {
        expect(authController.isValidName('John Doe'), true);
        expect(authController.isValidName('Jane'), true);
        expect(authController.isValidName(''), false); // Empty
        expect(authController.isValidName('A'), false); // Too short
        expect(authController.isValidName('A' * 101), false); // Too long
      });
    });

    group('state management', () {
      test('should notify listeners when user state changes', () {
        // Arrange
        bool notified = false;
        authController.addListener(() {
          notified = true;
        });

        // Act
        authController.setUser(UserModel(
          uid: 'test-uid',
          email: 'test@example.com',
          name: 'Test User',
        ));

        // Assert
        expect(notified, true);
        expect(authController.isLoggedIn, true);
      });

      test('should clear user state on logout', () {
        // Arrange
        authController.setUser(UserModel(
          uid: 'test-uid',
          email: 'test@example.com',
          name: 'Test User',
        ));
        expect(authController.isLoggedIn, true);

        // Act
        authController.clearUser();

        // Assert
        expect(authController.isLoggedIn, false);
        expect(authController.currentUser, null);
      });
    });
  });
}