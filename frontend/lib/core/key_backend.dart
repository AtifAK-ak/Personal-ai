import 'api_client.dart';
import 'direct/key_store.dart';
import 'direct/providers.dart';

/// Where the API keys live: on the phone (no server) or on the backend.
abstract class KeyBackend {
  Future<Map<String, dynamic>> list();
  Future<void> add(String provider, String key);
  Future<void> use(String provider, String id);
  Future<bool> test(String provider, String id);
  Future<void> revoke(String provider, String id);
  Future<void> setAuto(bool enabled);
}

class RemoteKeyBackend implements KeyBackend {
  RemoteKeyBackend(this.api);
  final ApiClient api;

  @override
  Future<Map<String, dynamic>> list() => api.request('GET', '/admin/keys');

  @override
  Future<void> add(String provider, String key) async {
    await api.request('POST', '/admin/keys/$provider', {'key': key});
  }

  @override
  Future<void> use(String provider, String id) async {
    await api.request('POST', '/admin/keys/$provider/active', {'id': id});
  }

  @override
  Future<bool> test(String provider, String id) async {
    final r = await api.request('POST', '/admin/keys/$provider/$id/test');
    return r['ok'] == true;
  }

  @override
  Future<void> revoke(String provider, String id) async {
    await api.request('DELETE', '/admin/keys/$provider/$id');
  }

  @override
  Future<void> setAuto(bool enabled) async {
    await api.request('POST', '/admin/keys/auto', {'enabled': enabled});
  }
}

class LocalKeyBackend implements KeyBackend {
  final KeyStore _s = KeyStore.instance;

  @override
  Future<Map<String, dynamic>> list() async {
    await _s.load();
    return _s.listing();
  }

  @override
  Future<void> add(String provider, String key) async {
    await _s.add(provider, key);
  }

  @override
  Future<void> use(String provider, String id) => _s.setActive(provider, id);

  @override
  Future<bool> test(String provider, String id) async {
    final key = _s.keyFor(provider, id);
    if (key == null) return false;
    final ok = await DirectProviders.probe(provider, key);
    await _s.mark(provider, id, ok);
    return ok;
  }

  @override
  Future<void> revoke(String provider, String id) => _s.revoke(provider, id);

  @override
  Future<void> setAuto(bool enabled) => _s.setAuto(enabled);
}
