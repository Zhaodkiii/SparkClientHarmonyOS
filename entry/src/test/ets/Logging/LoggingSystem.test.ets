import { describe, beforeEach, afterEach, it, expect } from '@ohos/hypium';
import { Logger, LoggerConfig } from '../../../main/ets/Foundation/Logging/Logger';
import { LogLevel } from '../../../main/ets/Foundation/Logging/LogLevel';
import { LogModule } from '../../../main/ets/Foundation/Logging/LogModule';
import { LogEvent, LogFields, isValidEventName } from '../../../main/ets/Foundation/Logging/LogEvent';
import { LogSanitizer } from '../../../main/ets/Foundation/Logging/LogSanitizer';
import { ErrorLogger } from '../../../main/ets/Foundation/Logging/ErrorLogger';
import { NetworkLogger } from '../../../main/ets/Foundation/Logging/NetworkLogger';

export default function loggingSystemTest() {
  describe('LoggingSystem', () => {
    const captured: string[] = [];

    beforeEach(() => {
      captured.length = 0;
      Logger.resetForTests();
      const config = new LoggerConfig();
      config.minLevel = LogLevel.DEBUG;
      Logger.configure(config);
      Logger.setCaptureSinkForTests((line: string, _level: LogLevel) => {
        captured.push(line);
      });
    });

    afterEach(() => {
      Logger.resetForTests();
    });

    it('level_filter_drops_verbose_when_min_is_info', 0, () => {
      const config = new LoggerConfig();
      config.minLevel = LogLevel.INFO;
      Logger.configure(config);
      captured.length = 0;
      Logger.debug('app.debug_only', LogModule.APP);
      Logger.info('app.info_ok', LogModule.APP);
      expect(captured.length).assertEqual(1);
      expect(captured[0]).assertContain('app.info_ok');
    });

    it('invalid_event_name_replaced', 0, () => {
      expect(isValidEventName('Bad Event!')).assertFalse();
      expect(isValidEventName('network.request.ok')).assertTrue();
      Logger.info('Bad Event!', LogModule.GENERAL);
      expect(captured[0]).assertContain('general.invalid_event');
    });

    it('sanitizer_redacts_bearer_password_phone_email', 0, () => {
      const text = LogSanitizer.redactPlainText(
        'Bearer abc.def.ghi "password":"secret" 13812345678 user@example.com'
      );
      expect(text).assertContain('<redacted>');
      expect(text).assertContain('<phone>');
      expect(text).assertContain('<email>');
      expect(text.indexOf('abc.def.ghi') < 0).assertTrue();
      expect(text.indexOf('secret') < 0).assertTrue();
    });

    it('singleLineSnippet_truncates_to_200', 0, () => {
      let long = '';
      for (let i = 0; i < 300; i++) {
        long += 'a';
      }
      const snip = LogSanitizer.singleLineSnippet(long, 200);
      expect(snip.length > 200).assertTrue();
      expect(snip).assertContain('…(len=300)');
    });

    it('sanitizeLogEvent_truncates_detail', 0, () => {
      const ev = new LogEvent('network.request.failed', LogModule.NETWORK, LogLevel.ERROR);
      let long = '';
      for (let i = 0; i < 250; i++) {
        long += 'x';
      }
      ev.detail = long;
      const safe = LogSanitizer.sanitizeLogEvent(ev);
      expect((safe.detail ?? '').length <= 220).assertTrue();
    });

    it('errorLogger_no_stack_in_summary', 0, () => {
      const err = new Error('boom Bearer tokensecret');
      const summary = ErrorLogger.summarize(err);
      expect(summary).assertContain('Error');
      expect(summary).assertContain('<redacted>');
      expect(summary.indexOf('tokensecret') < 0).assertTrue();
    });

    it('networkLogger_emits_structured_outbound', 0, () => {
      const net = new NetworkLogger(LogLevel.DEBUG);
      net.outbound('GET', 'https://api.example.com/api/v1/x/', 'req_1', { Authorization: 'Bearer secret' });
      expect(captured.length).assertEqual(1);
      expect(captured[0]).assertContain('network.request.outbound');
      expect(captured[0]).assertContain('req_1');
      expect(captured[0]).assertContain('<redacted>');
      expect(captured[0].indexOf('Bearer secret') < 0).assertTrue();
    });

    it('logger_fields_whitelist', 0, () => {
      const fields = new LogFields();
      fields.requestId = 'rid';
      fields.code = 401;
      fields.elapsedMs = 12.6;
      fields.retryCount = 1;
      fields.detail = 'timeout';
      Logger.warn('network.request.failed', LogModule.NETWORK, fields);
      expect(captured[0]).assertContain('"requestId":"rid"');
      expect(captured[0]).assertContain('"code":401');
      expect(captured[0]).assertContain('"elapsedMs":13');
      expect(captured[0]).assertContain('timeout');
    });
  });
}
