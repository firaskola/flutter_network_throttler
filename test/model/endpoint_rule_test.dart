import 'package:flutter_network_throttler/flutter_network_throttler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EndpointRule matching', () {
    test('matches an exact path', () {
      const rule = EndpointRule(
        method: 'GET',
        pattern: '/v1/feed',
        action: DelayAction(Duration(milliseconds: 800)),
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/v1/feed?page=2')),
        isTrue,
      );
      expect(
        rule.matches('POST', Uri.parse('https://api.test/v1/feed')),
        isFalse,
        reason: 'method mismatch',
      );
    });

    test('null method matches any method', () {
      const rule = EndpointRule(
        pattern: '/v1/feed',
        action: PassThroughAction(),
      );
      expect(
        rule.matches('DELETE', Uri.parse('https://api.test/v1/feed')),
        isTrue,
      );
    });

    test('glob wildcards match across segments', () {
      const rule = EndpointRule(
        pattern: '*.cdn.img/*',
        action: PassThroughAction(),
      );
      expect(
        rule.matches('GET', Uri.parse('https://assets.cdn.img/hero.webp')),
        isTrue,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/v1/feed')),
        isFalse,
      );
    });

    test('unanchored pattern matches as a substring', () {
      const rule = EndpointRule(
        pattern: '/v1/feed',
        action: PassThroughAction(),
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/api/v1/feed/extra')),
        isTrue,
        reason: 'default substring matching',
      );
    });

    test('anchored pattern requires the whole path to match', () {
      const rule = EndpointRule(
        pattern: '/v1/feed',
        action: PassThroughAction(),
        anchored: true,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/v1/feed?page=2')),
        isTrue,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/api/v1/feed/extra')),
        isFalse,
        reason: 'anchoring rejects the substring match',
      );
    });

    test('host constraint must match the request host', () {
      const rule = EndpointRule(
        pattern: '*',
        host: '*.cdn.example.com',
        action: PassThroughAction(),
      );
      expect(
        rule.matches('GET', Uri.parse('https://img.cdn.example.com/a.png')),
        isTrue,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.example.com/a.png')),
        isFalse,
      );
    });

    test('query constraint must be present and match', () {
      const rule = EndpointRule(
        pattern: '/search',
        query: {'q': '*', 'sort': 'desc'},
        action: PassThroughAction(),
      );
      expect(
        rule.matches(
          'GET',
          Uri.parse('https://api.test/search?q=cats&sort=desc'),
        ),
        isTrue,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/search?q=cats')),
        isFalse,
        reason: 'missing sort=desc',
      );
    });

    test('header constraint matches case-insensitively', () {
      const rule = EndpointRule(
        pattern: '/v1/feed',
        headers: {'authorization': 'Bearer *'},
        action: FailAction(FailureType.http403),
      );
      expect(
        rule.matches(
          'GET',
          Uri.parse('https://api.test/v1/feed'),
          requestHeaders: {'Authorization': 'Bearer abc123'},
        ),
        isTrue,
      );
      expect(
        rule.matches(
          'GET',
          Uri.parse('https://api.test/v1/feed'),
          requestHeaders: {'authorization': 'Basic xyz'},
        ),
        isFalse,
      );
      expect(
        rule.matches('GET', Uri.parse('https://api.test/v1/feed')),
        isFalse,
        reason: 'no headers supplied',
      );
    });
  });

  group('RuleAction labels and kinds', () {
    test('delay action', () {
      const a = DelayAction(Duration(milliseconds: 800));
      expect(a.label, '+800ms');
      expect(a.kind, RuleKind.slow);
    });

    test('fail action', () {
      const a = FailAction(FailureType.http500);
      expect(a.label, 'fail 500');
      expect(a.kind, RuleKind.fail);
    });

    test('pass-through action', () {
      const a = PassThroughAction();
      expect(a.label, 'pass-through');
      expect(a.kind, RuleKind.pass);
    });

    test('actions compare by value', () {
      expect(
        const DelayAction(Duration(milliseconds: 800)),
        const DelayAction(Duration(milliseconds: 800)),
      );
      expect(
        const FailAction(FailureType.http500),
        isNot(const FailAction(FailureType.http403)),
      );
    });
  });
}
