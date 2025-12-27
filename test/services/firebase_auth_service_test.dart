import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:room_ease/services/firebase_auth_service.dart';

// Generate mocks
@GenerateMocks([
  FirebaseAuth,
  User,
  UserCredential,
  GoogleSignIn,
  GoogleSignInAccount,
  GoogleSignInAuthentication,
])
import 'firebase_auth_service_test.mocks.dart';

void main() {
  group('FirebaseAuthService', () {
    late FirebaseAuthService firebaseAuthService;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockGoogleSignIn mockGoogleSignIn;
    late MockUser mockUser;
    late MockUserCredential mockUserCredential;
    late MockGoogleSignInAccount mockGoogleSignInAccount;
    late MockGoogleSignInAuthentication mockGoogleSignInAuthentication;

    setUp(() {
      mockFirebaseAuth = MockFirebaseAuth();
      mockGoogleSignIn = MockGoogleSignIn();
      mockUser = MockUser();
      mockUserCredential = MockUserCredential();
      mockGoogleSignInAccount = MockGoogleSignInAccount();
      mockGoogleSignInAuthentication = MockGoogleSignInAuthentication();
      
      firebaseAuthService = FirebaseAuthService(
        firebaseAuth: mockFirebaseAuth,
        googleSignIn: mockGoogleSignIn,
      );
    });

    group('signInWithEmailAndPassword', () {
      test('should sign in successfully with valid credentials', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockUser.uid).thenReturn('test-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.emailVerified).thenReturn(true);
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await firebaseAuthService.signInWithEmailAndPassword(email, password);

        // Assert
        expect(result, equals(mockUserCredential));
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('should throw FirebaseAuthException for invalid credentials', () async {
        // Arrange
        const email = 'invalid@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'user-not-found',
          message: 'No user found for that email.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('should throw FirebaseAuthException for wrong password', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'wrongpassword';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'wrong-password',
          message: 'Wrong password provided for that user.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('should throw FirebaseAuthException for disabled user', () async {
        // Arrange
        const email = 'disabled@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'user-disabled',
          message: 'The user account has been disabled by an administrator.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });
    });

    group('createUserWithEmailAndPassword', () {
      test('should create user successfully', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = 'password123';
        
        when(mockUser.uid).thenReturn('new-uid-123');
        when(mockUser.email).thenReturn(email);
        when(mockUser.emailVerified).thenReturn(false);
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await firebaseAuthService.createUserWithEmailAndPassword(email, password);

        // Assert
        expect(result, equals(mockUserCredential));
        verify(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('should throw FirebaseAuthException for weak password', () async {
        // Arrange
        const email = 'newuser@example.com';
        const password = '123';
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'weak-password',
          message: 'The password provided is too weak.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.createUserWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });

      test('should throw FirebaseAuthException for email already in use', () async {
        // Arrange
        const email = 'existing@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'email-already-in-use',
          message: 'The account already exists for that email.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.createUserWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        )).called(1);
      });
    });

    group('signInWithGoogle', () {
      test('should sign in with Google successfully', () async {
        // Arrange
        const idToken = 'google-id-token';
        const accessToken = 'google-access-token';
        
        when(mockGoogleSignInAuthentication.idToken).thenReturn(idToken);
        when(mockGoogleSignInAuthentication.accessToken).thenReturn(accessToken);
        when(mockGoogleSignInAccount.authentication)
            .thenAnswer((_) async => mockGoogleSignInAuthentication);
        when(mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockGoogleSignInAccount);
        
        when(mockUser.uid).thenReturn('google-uid-123');
        when(mockUser.email).thenReturn('google@example.com');
        when(mockUser.displayName).thenReturn('Google User');
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuth.signInWithCredential(any))
            .thenAnswer((_) async => mockUserCredential);

        // Act
        final result = await firebaseAuthService.signInWithGoogle();

        // Assert
        expect(result, equals(mockUserCredential));
        verify(mockGoogleSignIn.signIn()).called(1);
        verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      });

      test('should return null when Google sign-in is cancelled', () async {
        // Arrange
        when(mockGoogleSignIn.signIn()).thenAnswer((_) async => null);

        // Act
        final result = await firebaseAuthService.signInWithGoogle();

        // Assert
        expect(result, isNull);
        verify(mockGoogleSignIn.signIn()).called(1);
        verifyNever(mockFirebaseAuth.signInWithCredential(any));
      });

      test('should throw exception when Google authentication fails', () async {
        // Arrange
        when(mockGoogleSignIn.signIn())
            .thenThrow(Exception('Google sign-in failed'));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithGoogle(),
          throwsA(isA<Exception>()),
        );
        
        verify(mockGoogleSignIn.signIn()).called(1);
        verifyNever(mockFirebaseAuth.signInWithCredential(any));
      });

      test('should throw exception when Firebase credential sign-in fails', () async {
        // Arrange
        const idToken = 'google-id-token';
        const accessToken = 'google-access-token';
        
        when(mockGoogleSignInAuthentication.idToken).thenReturn(idToken);
        when(mockGoogleSignInAuthentication.accessToken).thenReturn(accessToken);
        when(mockGoogleSignInAccount.authentication)
            .thenAnswer((_) async => mockGoogleSignInAuthentication);
        when(mockGoogleSignIn.signIn())
            .thenAnswer((_) async => mockGoogleSignInAccount);
        
        when(mockFirebaseAuth.signInWithCredential(any))
            .thenThrow(FirebaseAuthException(
              code: 'account-exists-with-different-credential',
              message: 'An account already exists with the same email address.',
            ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithGoogle(),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockGoogleSignIn.signIn()).called(1);
        verify(mockFirebaseAuth.signInWithCredential(any)).called(1);
      });
    });

    group('signOut', () {
      test('should sign out successfully', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

        // Act
        await firebaseAuthService.signOut();

        // Assert
        verify(mockFirebaseAuth.signOut()).called(1);
        verify(mockGoogleSignIn.signOut()).called(1);
      });

      test('should handle Firebase sign out failure', () async {
        // Arrange
        when(mockFirebaseAuth.signOut())
            .thenThrow(Exception('Firebase sign out failed'));
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

        // Act & Assert
        expect(
          () => firebaseAuthService.signOut(),
          throwsA(isA<Exception>()),
        );
        
        verify(mockFirebaseAuth.signOut()).called(1);
        // Google sign out should still be called even if Firebase fails
        verify(mockGoogleSignIn.signOut()).called(1);
      });

      test('should handle Google sign out failure gracefully', () async {
        // Arrange
        when(mockFirebaseAuth.signOut()).thenAnswer((_) async {});
        when(mockGoogleSignIn.signOut())
            .thenThrow(Exception('Google sign out failed'));

        // Act
        await firebaseAuthService.signOut();

        // Assert
        verify(mockFirebaseAuth.signOut()).called(1);
        verify(mockGoogleSignIn.signOut()).called(1);
        // Should not throw exception for Google sign out failure
      });
    });

    group('sendPasswordResetEmail', () {
      test('should send password reset email successfully', () async {
        // Arrange
        const email = 'reset@example.com';
        
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenAnswer((_) async {});

        // Act
        await firebaseAuthService.sendPasswordResetEmail(email);

        // Assert
        verify(mockFirebaseAuth.sendPasswordResetEmail(email: email)).called(1);
      });

      test('should throw FirebaseAuthException for invalid email', () async {
        // Arrange
        const email = 'invalid@example.com';
        
        when(mockFirebaseAuth.sendPasswordResetEmail(email: email))
            .thenThrow(FirebaseAuthException(
              code: 'user-not-found',
              message: 'No user found for that email.',
            ));

        // Act & Assert
        expect(
          () => firebaseAuthService.sendPasswordResetEmail(email),
          throwsA(isA<FirebaseAuthException>()),
        );
        
        verify(mockFirebaseAuth.sendPasswordResetEmail(email: email)).called(1);
      });
    });

    group('updateDisplayName', () {
      test('should update display name successfully', () async {
        // Arrange
        const displayName = 'Updated Name';
        
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName(displayName)).thenAnswer((_) async {});

        // Act
        await firebaseAuthService.updateDisplayName(displayName);

        // Assert
        verify(mockUser.updateDisplayName(displayName)).called(1);
      });

      test('should throw exception when no current user', () async {
        // Arrange
        const displayName = 'Updated Name';
        
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act & Assert
        expect(
          () => firebaseAuthService.updateDisplayName(displayName),
          throwsA(isA<Exception>()),
        );
        
        verifyNever(mockUser.updateDisplayName(any));
      });

      test('should throw exception when update fails', () async {
        // Arrange
        const displayName = 'Updated Name';
        
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);
        when(mockUser.updateDisplayName(displayName))
            .thenThrow(Exception('Update failed'));

        // Act & Assert
        expect(
          () => firebaseAuthService.updateDisplayName(displayName),
          throwsA(isA<Exception>()),
        );
        
        verify(mockUser.updateDisplayName(displayName)).called(1);
      });
    });

    group('getCurrentUser', () {
      test('should return current user when signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = firebaseAuthService.getCurrentUser();

        // Assert
        expect(result, equals(mockUser));
        verify(mockFirebaseAuth.currentUser).called(1);
      });

      test('should return null when not signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = firebaseAuthService.getCurrentUser();

        // Assert
        expect(result, isNull);
        verify(mockFirebaseAuth.currentUser).called(1);
      });
    });

    group('isUserSignedIn', () {
      test('should return true when user is signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(mockUser);

        // Act
        final result = firebaseAuthService.isUserSignedIn();

        // Assert
        expect(result, true);
        verify(mockFirebaseAuth.currentUser).called(1);
      });

      test('should return false when user is not signed in', () {
        // Arrange
        when(mockFirebaseAuth.currentUser).thenReturn(null);

        // Act
        final result = firebaseAuthService.isUserSignedIn();

        // Assert
        expect(result, false);
        verify(mockFirebaseAuth.currentUser).called(1);
      });
    });

    group('authStateChanges', () {
      test('should return auth state changes stream', () {
        // Arrange
        final Stream<User?> mockStream = Stream.value(mockUser);
        when(mockFirebaseAuth.authStateChanges()).thenAnswer((_) => mockStream);

        // Act
        final result = firebaseAuthService.authStateChanges();

        // Assert
        expect(result, equals(mockStream));
        verify(mockFirebaseAuth.authStateChanges()).called(1);
      });
    });

    group('edge cases and error handling', () {
      test('should handle network errors gracefully', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'network-request-failed',
          message: 'A network error has occurred.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
      });

      test('should handle too many requests error', () async {
        // Arrange
        const email = 'test@example.com';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'too-many-requests',
          message: 'Too many unsuccessful login attempts.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
      });

      test('should handle invalid email format', () async {
        // Arrange
        const email = 'invalid-email-format';
        const password = 'password123';
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenThrow(FirebaseAuthException(
          code: 'invalid-email',
          message: 'The email address is badly formatted.',
        ));

        // Act & Assert
        expect(
          () => firebaseAuthService.signInWithEmailAndPassword(email, password),
          throwsA(isA<FirebaseAuthException>()),
        );
      });
    });

    group('concurrent operations', () {
      test('should handle concurrent sign-in attempts', () async {
        // Arrange
        const email = 'concurrent@example.com';
        const password = 'password123';
        
        when(mockUser.uid).thenReturn('concurrent-uid');
        when(mockUser.email).thenReturn(email);
        when(mockUserCredential.user).thenReturn(mockUser);
        
        when(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).thenAnswer((_) async => mockUserCredential);

        // Act
        final futures = List.generate(3, (_) => 
          firebaseAuthService.signInWithEmailAndPassword(email, password)
        );
        final results = await Future.wait(futures);

        // Assert
        expect(results.length, 3);
        for (final result in results) {
          expect(result, equals(mockUserCredential));
        }
        
        verify(mockFirebaseAuth.signInWithEmailAndPassword(
          email: email,
          password: password,
        )).called(3);
      });
    });
  });
}