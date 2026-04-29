enum BackendProvider { local, supabase, firebase }

class BackendConfig {
  static const BackendProvider provider = BackendProvider.local;

  static bool get isLocal => provider == BackendProvider.local;
  static bool get isSupabase => provider == BackendProvider.supabase;
  static bool get isFirebase => provider == BackendProvider.firebase;
}
