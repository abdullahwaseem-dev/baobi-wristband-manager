/// Firebase project configuration — app-wide (one Firebase project serves
/// every hospital; each hospital gets its own Auth account within it, see
/// FirebaseAuthService). Mutable so tests can repoint every base URL at the
/// local emulator suite without touching call sites.
class FirebaseEnv {
  FirebaseEnv._();

  // Baobi production Firebase project (Blaze plan). Web API Key is a project
  // identifier, not a secret in the traditional sense — real access control
  // comes from Firestore Security Rules + per-hospital Auth, not from
  // keeping this value hidden (that's why it's safe to compile into a
  // client app, unlike the Admin SDK service account key, which must never
  // appear here).
  static String projectId = 'baobi-8eb0c';
  static String apiKey = 'AIzaSyCs0e32pYi1JBM_Tu1DlTKnGoRI1kT_iY8';

  static String identityToolkitBaseUrl = 'https://identitytoolkit.googleapis.com';
  static String secureTokenBaseUrl = 'https://securetoken.googleapis.com';
  static String firestoreBaseUrl = 'https://firestore.googleapis.com';

  static bool get isConfigured => projectId.isNotEmpty && apiKey.isNotEmpty;

  /// Repoints every base URL at a local Firebase Emulator Suite instance.
  /// Test-only; production code never calls this.
  static void useEmulator({
    required String projectId,
    String host = '127.0.0.1',
    int authPort = 9099,
    int firestorePort = 8080,
  }) {
    FirebaseEnv.projectId = projectId;
    apiKey = 'fake-api-key'; // emulator ignores the key's actual value
    identityToolkitBaseUrl = 'http://$host:$authPort/identitytoolkit.googleapis.com';
    secureTokenBaseUrl = 'http://$host:$authPort/securetoken.googleapis.com';
    firestoreBaseUrl = 'http://$host:$firestorePort';
  }
}
