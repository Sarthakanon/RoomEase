/**
 * Helper script to get Firebase ID token for testing
 * 
 * Usage:
 * 1. Install Firebase SDK: npm install firebase
 * 2. Update the test user credentials below
 * 3. Run: node get-firebase-token.js
 */

const { initializeApp } = require('firebase/app');
const { getAuth, signInWithEmailAndPassword } = require('firebase/auth');

// Firebase configuration for RoomEase
const firebaseConfig = {
  apiKey: "AIzaSyC8epfR3MAWSYMaqk9VXXYVjSQMKG9fEbA",
  authDomain: "roomease-2025.firebaseapp.com",
  projectId: "roomease-2025",
  storageBucket: "roomease-2025.firebasestorage.app",
  messagingSenderId: "949338416443",
  appId: "1:949338416443:web:e958d1632234a75590431e"
};

// Test user credentials - update with your test user
const testUser = {
  email: "test@example.com",
  password: "testpassword123"
};

async function getFirebaseToken() {
  try {
    // Initialize Firebase
    const app = initializeApp(firebaseConfig);
    const auth = getAuth(app);

    // Sign in user
    console.log('Signing in user...');
    const userCredential = await signInWithEmailAndPassword(
      auth, 
      testUser.email, 
      testUser.password
    );

    // Get ID token
    console.log('Getting ID token...');
    const idToken = await userCredential.user.getIdToken();

    console.log('\n✅ Firebase ID Token:');
    console.log(idToken);
    console.log('\n📋 Copy this token to your Bruno environment variables');
    console.log('⚠️  Note: This token expires in 1 hour');

    // Get token expiration
    const tokenResult = await userCredential.user.getIdTokenResult();
    console.log(`\n⏰ Token expires at: ${tokenResult.expirationTime}`);

    // Show user info
    console.log(`\n👤 User Info:`);
    console.log(`   UID: ${userCredential.user.uid}`);
    console.log(`   Email: ${userCredential.user.email}`);
    console.log(`   Display Name: ${userCredential.user.displayName || 'Not set'}`);

  } catch (error) {
    console.error('❌ Error getting Firebase token:', error.message);
    
    if (error.code === 'auth/user-not-found') {
      console.log('💡 Create a test user in Firebase Console first');
      console.log('   1. Go to Firebase Console > Authentication > Users');
      console.log('   2. Click "Add user"');
      console.log(`   3. Email: ${testUser.email}`);
      console.log(`   4. Password: ${testUser.password}`);
    } else if (error.code === 'auth/wrong-password') {
      console.log('💡 Check the password for your test user');
    } else if (error.code === 'auth/invalid-api-key') {
      console.log('💡 Firebase configuration is incorrect');
    } else if (error.code === 'auth/network-request-failed') {
      console.log('💡 Check your internet connection');
    }
  }
}

// Run the function
getFirebaseToken();