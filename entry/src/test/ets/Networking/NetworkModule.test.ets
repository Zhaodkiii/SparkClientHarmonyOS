import { describe, beforeEach, it, expect } from '@ohos/hypium';
import {
  AuthTokens,
  CancellationToken,
  NetworkRequest,
  NetworkStrategy,
  QueryItem,
  RawHttpResponse,
  RetryConfig,
  SupportNetworkError,
  buildURLWithQuery,
  joinBaseURLAndPath,
  makeRequestId,
  NetworkResponse
} from '../../../main/ets/Projects/Core/Networking/SupportNetworkModels';
import { MockNetworkTransport } from '../../../main/ets/Projects/Core/Networking/SupportNetworkTransport';
import { SupportAPIResponseDecoder } from '../../../main/ets/Projects/Core/Networking/API/Common/SupportAPIResponseDecoder';
import { AuthTokenProvider } from '../../../main/ets/Projects/Core/Networking/AuthTokenProvider';
import { SecureTokenStore } from '../../../main/ets/Foundation/Security/SecureTokenStore';
import { SupportNetworkEngine } from '../../../main/ets/Projects/Core/Networking/SupportNetworkEngine';
import { DeviceCache } from '../../../main/ets/Projects/Core/Networking/Caching/DeviceCache';
import { ETagStore } from '../../../main/ets/Projects/Core/Networking/ETagStore';
import { SupportCallbackCache } from '../../../main/ets/Projects/Core/Networking/Caching/SupportCallbackCache';
import { SerialRequestGate } from '../../../main/ets/Projects/Core/Networking/SerialRequestGate';
import { LogSanitizer } from '../../../main/ets/Foundation/Logging/LogSanitizer';
import { SessionInvalidation } from '../../../main/ets/Projects/Core/Networking/SessionInvalidation';
import { JWTExpParser } from '../../../main/ets/Foundation/JWTExpParser';
import { RetryAfterParser } from '../../../main/ets/Projects/Core/Networking/RetryLayer';

function makeEngine(transport: MockNetworkTransport, filesDir: string = '/tmp/support-net-test'): SupportNetworkEngine {
  const cache = DeviceCache.memoryOnly();
  const store = new SecureTokenStore(filesDir);
  const auth = new AuthTokenProvider(transport, 'https://api.example.com', store);
  const etag = new ETagStore(filesDir);
  return new SupportNetworkEngine('https://api.example.com', transport, auth, etag, cache);
}

export default function networkModuleTest() {
  describe('NetworkModule', () => {
    beforeEach(() => {
      SessionInvalidation.resetForTests();
    });

    it('joinBaseURLAndPath_normalizes_slashes', 0, () => {
      expect(joinBaseURLAndPath('https://a.com/', '/api/v1/x/')).assertEqual('https://a.com/api/v1/x/');
      expect(joinBaseURLAndPath('https://a.com', 'api/v1/x/')).assertEqual('https://a.com/api/v1/x/');
      expect(joinBaseURLAndPath('https://a.com/', 'api/v1/x/')).assertEqual('https://a.com/api/v1/x/');
    });

    it('buildURLWithQuery_sorts_and_encodes', 0, () => {
      const url = buildURLWithQuery('https://a.com', '/api/', [
        new QueryItem('b', '2'),
        new QueryItem('a', '1 2')
      ]);
      expect(url).assertEqual('https://a.com/api/?a=1%202&b=2');
    });

    it('decodeWrapped_success_and_business_error', 0, () => {
      const ok = new NetworkResponse(200, {}, '{"code":0,"msg":"ok","data":{"userId":1}}', false, 'r1');
      const userId = SupportAPIResponseDecoder.decodeWrappedData(ok, (data) => {
        const obj = SupportAPIResponseDecoder.asRecord(data);
        return SupportAPIResponseDecoder.num(obj, 'userId');
      });
      expect(userId).assertEqual(1);

      const bad = new NetworkResponse(200, {}, '{"code":40001,"msg":"fail","data":null}', false, 'r2');
      let threw = false;
      try {
        SupportAPIResponseDecoder.decodeWrappedData(bad, (_d) => null);
      } catch (e) {
        threw = e instanceof SupportNetworkError && (e as SupportNetworkError).kind === 'business';
      }
      expect(threw).assertTrue();
    });

    it('decodeDirect_token_refresh_shape', 0, () => {
      const resp = new NetworkResponse(200, {}, '{"access":"a","refresh":"b","token_type":"Bearer"}', false, 'r3');
      const access = SupportAPIResponseDecoder.decodeDirect(resp, (root) => {
        const obj = SupportAPIResponseDecoder.asRecord(root);
        return SupportAPIResponseDecoder.str(obj, 'access');
      });
      expect(access).assertEqual('a');
    });

    it('logSanitizer_redacts_authorization', 0, () => {
      const preview = LogSanitizer.headersPreview({ Authorization: 'Bearer secret-token', 'X-Request-ID': 'abc' });
      expect(preview).assertContain('<redacted>');
      expect(preview).assertContain('abc');
      const body = LogSanitizer.bodySummary('{"password":"p","userId":1}');
      expect(body).assertContain('<redacted>');
      expect(body).assertContain('userId');
    });

    it('callbackCache_merges_inflight_get', 0, async () => {
      const cache = new SupportCallbackCache();
      let calls = 0;
      const factory = async (): Promise<NetworkResponse> => {
        calls += 1;
        await new Promise<void>((r) => setTimeout(r, 20));
        return new NetworkResponse(200, {}, '{}', false, makeRequestId());
      };
      const p1 = cache.execute('GET|/x||anon', 'op', factory);
      const p2 = cache.execute('GET|/x||anon', 'op', factory);
      await Promise.all([p1, p2]);
      expect(calls).assertEqual(1);
      expect(cache.size()).assertEqual(0);
    });

    it('serialGate_same_key_runs_serially', 0, async () => {
      const gate = new SerialRequestGate();
      const order: number[] = [];
      const t1 = gate.enqueue('k', 'normal', async () => {
        await new Promise<void>((r) => setTimeout(r, 30));
        order.push(1);
        return 1;
      });
      const t2 = gate.enqueue('k', 'normal', async () => {
        order.push(2);
        return 2;
      });
      await Promise.all([t1, t2]);
      expect(order[0]).assertEqual(1);
      expect(order[1]).assertEqual(2);
    });

    it('non_idempotent_post_does_not_retry', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueueFixed(new RawHttpResponse(500, {}, '{"code":500,"msg":"err"}', 1));
      transport.enqueueFixed(new RawHttpResponse(200, {}, '{"code":0,"msg":"ok","data":{}}', 1));
      const engine = makeEngine(transport);
      let threw = false;
      try {
        await engine.sendRaw(new NetworkRequest(
          'POST',
          '/api/v1/x/',
          new NetworkStrategy(false, false, undefined, false, 'normal', RetryConfig.defaultConfig()),
          [],
          {},
          {}
        ));
      } catch (e) {
        threw = e instanceof SupportNetworkError;
      }
      expect(threw).assertTrue();
      expect(transport.sentRequests.length).assertEqual(1);
    });

    it('idempotent_get_retries_on_500', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueueFixed(new RawHttpResponse(500, {}, 'err', 1));
      transport.enqueueFixed(new RawHttpResponse(200, {}, 'ok', 1));
      const engine = makeEngine(transport);
      const resp = await engine.sendRaw(new NetworkRequest(
        'GET',
        '/api/v1/x/',
        new NetworkStrategy(false, false, undefined, true, 'normal', new RetryConfig(true, 2, [500], false, [0, 0, 0]))
      ));
      expect(resp.statusCode).assertEqual(200);
      expect(transport.sentRequests.length).assertEqual(2);
    });

    it('auth_header_only_when_requiresAuth', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueueFixed(new RawHttpResponse(200, {}, 'ok', 1));
      const engine = makeEngine(transport);
      await engine.tokenProvider().setTokens(new AuthTokens('acc', 'ref', Date.now() + 3600000, 'Bearer'));
      await engine.sendRaw(new NetworkRequest('GET', '/public/', new NetworkStrategy(false)));
      expect(transport.sentRequests[0].headers['Authorization'] === undefined).assertTrue();

      transport.enqueueFixed(new RawHttpResponse(200, {}, 'ok', 1));
      await engine.sendRaw(new NetworkRequest('GET', '/private/', new NetworkStrategy(true, false, undefined, true)));
      expect(transport.sentRequests[1].headers['Authorization']).assertEqual('Bearer acc');
    });

    it('401_refresh_replays_once', 0, async () => {
      const transport = new MockNetworkTransport();
      const engine = makeEngine(transport);
      await engine.tokenProvider().setTokens(new AuthTokens('old', 'ref', Date.now() + 3600000, 'Bearer'));

      // first business call → 401
      transport.enqueueFixed(new RawHttpResponse(401, {}, '{"code":40100,"msg":"token_expired"}', 1));
      // refresh call
      transport.enqueueFixed(new RawHttpResponse(200, {}, '{"access":"new","refresh":"ref2","token_type":"Bearer"}', 1));
      // replay
      transport.enqueueFixed(new RawHttpResponse(200, {}, 'ok', 1));

      const resp = await engine.sendRaw(new NetworkRequest('GET', '/api/v1/secure/', new NetworkStrategy(true, false, undefined, true)));
      expect(resp.statusCode).assertEqual(200);
      expect(transport.sentRequests.length).assertEqual(3);
      expect(transport.sentRequests[2].headers['Authorization']).assertContain('new');
    });

    it('refresh_single_flight', 0, async () => {
      const transport = new MockNetworkTransport();
      let refreshCalls = 0;
      transport.enqueue(async (_req) => {
        refreshCalls += 1;
        await new Promise<void>((r) => setTimeout(r, 40));
        return new RawHttpResponse(200, {}, '{"access":"a1","refresh":"r1"}', 40);
      });
      // concurrent refresh should share one promise; only one handler needed if single-flight works,
      // but second caller may race before promise set — enqueue a second just in case
      transport.enqueue(async (_req) => {
        refreshCalls += 1;
        return new RawHttpResponse(200, {}, '{"access":"a2","refresh":"r2"}', 1);
      });

      const store = new SecureTokenStore('/tmp/support-net-refresh');
      await store.save(new AuthTokens('old', 'ref', Date.now() - 1000, 'Bearer'));
      const provider = new AuthTokenProvider(transport, 'https://api.example.com', store);
      await provider.restoreIfNeeded();

      const p1 = provider.refreshIfNeeded(true);
      const p2 = provider.refreshIfNeeded(true);
      const [t1, t2] = await Promise.all([p1, p2]);
      expect(t1.accessToken).assertEqual(t2.accessToken);
      expect(refreshCalls).assertEqual(1);
    });

    it('refresh_uses_same_installation_device_id_as_login', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueueFixed(new RawHttpResponse(200, {}, '{"access":"new","refresh":"ref2"}', 1));
      const store = new SecureTokenStore('/tmp/support-net-device-binding');
      await store.save(new AuthTokens('old', 'ref', Date.now() - 1000, 'Bearer'));
      const provider = new AuthTokenProvider(
        transport,
        'https://api.example.com',
        store,
        undefined,
        () => 'persistent-device-id',
        () => 'cn.Zhaodk.Health'
      );

      await provider.refreshIfNeeded(true);
      const body = transport.sentRequests[0].body ?? '';
      expect(body).assertContain('persistent-device-id');
      expect(body).assertContain('cn.Zhaodk.Health');
      expect(body).assertContain('"refresh_token":"ref"');
    });

    it('refresh_default_bundle_id_matches_login_bundle_id', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueueFixed(new RawHttpResponse(200, {}, '{"access":"new","refresh":"ref2"}', 1));
      const store = new SecureTokenStore('/tmp/support-net-refresh-default-bundle');
      await store.save(new AuthTokens('old', 'ref', Date.now() - 1000, 'Bearer'));
      const provider = new AuthTokenProvider(
        transport,
        'https://api.example.com',
        store,
        undefined,
        () => 'persistent-device-id'
      );

      await provider.refreshIfNeeded(true);
      const body = transport.sentRequests[0].body ?? '';
      expect(body).assertContain('"bundle_id":"cn.Zhaodk.Health"');
    });

    it('cancellation_maps_to_cancelled', 0, async () => {
      const transport = new MockNetworkTransport();
      transport.enqueue(async (_req) => {
        await new Promise<void>((r) => setTimeout(r, 100));
        return new RawHttpResponse(200, {}, 'ok', 100);
      });
      const engine = makeEngine(transport);
      const token = new CancellationToken();
      const p = engine.sendRaw(new NetworkRequest('GET', '/x/', new NetworkStrategy(false, false, undefined, true)), token);
      token.cancel();
      let kind = '';
      try {
        await p;
      } catch (e) {
        if (e instanceof SupportNetworkError) {
          kind = e.kind;
        }
      }
      expect(kind).assertEqual('cancelled');
    });

    it('session_invalidation_deduped', 0, () => {
      let count = 0;
      SessionInvalidation.subscribe(() => {
        count += 1;
      });
      const a = SessionInvalidation.postIfNeeded(401, undefined, 'token_expired', 't1');
      const b = SessionInvalidation.postIfNeeded(401, undefined, 'token_expired', 't2');
      expect(a).assertTrue();
      expect(b).assertFalse();
      expect(count).assertEqual(1);
    });

    it('session_invalidation_403_never_forces_sign_out', 0, () => {
      const posted = SessionInvalidation.postIfNeeded(403, 40102, 'token_not_valid', 'permission');
      expect(posted).assertFalse();
      expect(SessionInvalidation.invalidating).assertFalse();
    });

    it('retry_after_parser_seconds', 0, () => {
      expect(RetryAfterParser.parseSeconds('2')).assertEqual(2);
    });

    it('jwt_exp_parser_reads_payload', 0, () => {
      // header.payload.sig — payload {"exp":2000000000}
      const payload = 'eyJleHAiOjIwMDAwMDAwMDB9';
      const token = `x.${payload}.y`;
      const exp = JWTExpParser.parseExpMs(token);
      expect(exp).assertEqual(2000000000 * 1000);
    });

    it('etag_cache_key_stable_sha256_and_differs_by_auth', 0, () => {
      const k1 = ETagStore.sha256Hex('https://a/x|Authorization:af1');
      const k2 = ETagStore.sha256Hex('https://a/x|Authorization:af1');
      const k3 = ETagStore.sha256Hex('https://a/x|Authorization:af2');
      expect(k1).assertEqual(k2);
      expect(k1 === k3).assertFalse();
      expect(k1.length).assertEqual(64);
      const store = new ETagStore(`/tmp/etag-key-${Date.now()}`);
      const ck1 = store.cacheKey('https://a/x', 'af1');
      const ck2 = store.cacheKey('https://a/x', 'af2');
      expect(ck1).assertEqual(k1);
      expect(ck1 === ck2).assertFalse();
    });

    it('etag_apply_sends_max_age_always_and_removes_expired', 0, () => {
      const filesDir = `/tmp/etag-expire-${Date.now()}`;
      const store = new ETagStore(filesDir);
      const scope = 'acct_test';
      const key = store.cacheKey('https://api.example.com/api/v1/x/', 'af1');
      store.write(scope, key, '"etag-old"', '{"code":0,"data":null}', Date.now() - 1000);

      const headers: Record<string, string> = {};
      const req = new NetworkRequest(
        'GET',
        '/api/v1/x/',
        new NetworkStrategy(true, true, 'medical.resource.list.members', true, 'normal', RetryConfig.defaultConfig(), 120000)
      );
      store.applyIfNoneMatch(headers, scope, key, req);
      expect(headers['X-Cache-Max-Age']).assertEqual('120');
      expect(headers['If-None-Match'] === undefined).assertTrue();
      expect(store.readMeta(scope, key) === undefined).assertTrue();
      expect(store.readBody(scope, key) === undefined).assertTrue();

      const headersFirst: Record<string, string> = {};
      const missingKey = store.cacheKey('https://api.example.com/api/v1/y/', 'af1');
      store.applyIfNoneMatch(headersFirst, scope, missingKey, req);
      expect(headersFirst['X-Cache-Max-Age']).assertEqual('120');
      expect(headersFirst['If-None-Match'] === undefined).assertTrue();
    });

    it('etag_apply_sets_if_none_match_when_fresh', 0, () => {
      const store = new ETagStore(`/tmp/etag-fresh-${Date.now()}`);
      const scope = 'acct_fresh';
      const key = store.cacheKey('https://api.example.com/api/v1/z/', 'af9');
      store.write(scope, key, '"etag-fresh"', '{"code":0}', Date.now() + 60000);
      const headers: Record<string, string> = {};
      const req = new NetworkRequest(
        'GET',
        '/api/v1/z/',
        new NetworkStrategy(true, true, 'k', true, 'normal', RetryConfig.defaultConfig(), 86400000)
      );
      store.applyIfNoneMatch(headers, scope, key, req);
      expect(headers['If-None-Match']).assertEqual('"etag-fresh"');
      expect(headers['X-Cache-Max-Age']).assertEqual('86400');
    });

    it('etag_merge_304_uses_local_body', 0, () => {
      const store = new ETagStore(`/tmp/etag-304-${Date.now()}`);
      const scope = 'acct_304';
      const key = store.cacheKey('https://api.example.com/api/v1/complete/', 'af2');
      const body = '{"code":0,"msg":"ok","data":{"member_id":1}}';
      store.write(scope, key, '"v1"', body, Date.now() + 60000);
      const req = new NetworkRequest(
        'GET',
        '/api/v1/complete/',
        new NetworkStrategy(true, true, 'medical.query./api/v1/complete/', true, 'normal', RetryConfig.defaultConfig(), 86400000)
      );
      const raw304 = new NetworkResponse(304, {}, '', false, 'rid-304');
      const merged = store.mergeResponse(scope, key, raw304, req);
      expect(merged.statusCode).assertEqual(200);
      expect(merged.didMerge304).assertTrue();
      expect(merged.bodyText).assertEqual(body);
    });

    it('etag_merge_304_decodes_utf8_body_without_mojibake', 0, () => {
      const store = new ETagStore(`/tmp/etag-utf8-${Date.now()}`);
      const scope = 'acct_utf8';
      const key = store.cacheKey('https://api.example.com/api/v1/utf8/', 'af3');
      const body = '{"code":0,"data":{"name":"妈妈","instructions":"口服"}}';
      store.write(scope, key, '"utf8-v1"', body, Date.now() + 60000);
      const req = new NetworkRequest(
        'GET',
        '/api/v1/utf8/',
        new NetworkStrategy(true, true, 'medical.utf8', true, 'normal', RetryConfig.defaultConfig(), 86400000)
      );
      const merged = store.mergeResponse(scope, key, new NetworkResponse(304, {}, '', false, 'rid-utf8'), req);
      expect(merged.bodyText).assertEqual(body);
      expect(merged.bodyText.indexOf('妈妈') >= 0).assertTrue();
      expect(merged.bodyText.indexOf('é') >= 0).assertFalse();
    });
  });
}
