import 'package:robot_controller/models/iaModo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('IaModo', () {
    test('o padrao e nuvem', () {
      expect(IaModo.fromCode(null), IaModo.nuvem);
    });

    test('le os codigos conhecidos', () {
      expect(IaModo.fromCode('local'), IaModo.local);
      expect(IaModo.fromCode('nuvem'), IaModo.nuvem);
    });

    test('codigo desconhecido vira o padrao, nunca erro', () {
      expect(IaModo.fromCode('gpt-9'), IaModo.nuvem);
      expect(IaModo.fromCode(''), IaModo.nuvem);
    });

    test('cada modo tem um code estavel (contrato com o robo)', () {
      expect(IaModo.local.code, 'local');
      expect(IaModo.nuvem.code, 'nuvem');
    });
  });
}
