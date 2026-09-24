import 'package:flutter_test/flutter_test.dart';
import 'package:pennypal/core/security.dart';
import 'package:pennypal/core/validators.dart';

void main() {
  group('Validators', () {
    test('email', () {
      expect(Validators.email('ada@uni.edu'), isNull);
      expect(Validators.email('a.b+c@mail.co.uk'), isNull);
      expect(Validators.email(''), isNotNull);
      expect(Validators.email('ada@'), isNotNull);
      expect(Validators.email('ada uni.edu'), isNotNull);
    });

    test('password rules', () {
      expect(Validators.password('Student@123'), isNull);
      expect(Validators.password('short1!A'), isNull);
      expect(Validators.password('alllowercase1!'), contains('upper-case'));
      expect(Validators.password('NoNumber!!'), contains('number'));
      expect(Validators.password('NoSymbol123'), contains('symbol'));
      expect(Validators.password('Ab1!'), contains('8+'));
    });

    test('mobile', () {
      expect(Validators.mobile('+15550100200'), isNull);
      expect(Validators.mobile('0803 123 4567'), isNull);
      expect(Validators.mobile('12ab'), isNotNull);
      expect(Validators.mobile('123'), isNotNull);
    });

    test('amount', () {
      expect(Validators.amount('12.50'), isNull);
      expect(Validators.amount('1,200'), isNull);
      expect(Validators.amount('0'), isNotNull);
      expect(Validators.amount('0', allowZero: true), isNull);
      expect(Validators.amount('-5'), isNotNull);
      expect(Validators.amount('abc'), isNotNull);
      expect(Validators.parseAmount('1,200.5'), 1200.5);
    });
  });

  group('PasswordHasher', () {
    test('verifies the right password only', () {
      final h = PasswordHasher.hash('Secret@123');
      expect(h, startsWith('pbkdf2\$'));
      expect(PasswordHasher.verify('Secret@123', h), isTrue);
      expect(PasswordHasher.verify('secret@123', h), isFalse);
    });

    test('uses a random salt', () {
      expect(PasswordHasher.hash('same'), isNot(PasswordHasher.hash('same')));
    });
  });
}
