import 'package:flutter_test/flutter_test.dart';
import 'package:smart_roll_call_flutter/models/student.dart';

void main() {
  group('ESP32 Integration Tests', () {
    test('Student model should handle MAC address', () {
      // Test student creation with MAC address
      final student = Student(
        id: 'test-id',
        name: 'John Doe',
        enrollNumber: '12345',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      expect(student.name, 'John Doe');
      expect(student.enrollNumber, '12345');
      expect(student.macAddress, 'AA:BB:CC:DD:EE:FF');
      expect(student.isPresent, false);
    });

    test('Student model should handle null MAC address', () {
      // Test student creation without MAC address
      final student = Student(
        id: 'test-id',
        name: 'Jane Doe',
        enrollNumber: '67890',
      );

      expect(student.name, 'Jane Doe');
      expect(student.enrollNumber, '67890');
      expect(student.macAddress, null);
      expect(student.isPresent, false);
    });

    test('Student toMap should include MAC address when present', () {
      final student = Student(
        id: 'test-id',
        name: 'John Doe',
        enrollNumber: '12345',
        macAddress: 'AA:BB:CC:DD:EE:FF',
      );

      final map = student.toMap();
      expect(map['name'], 'John Doe');
      expect(map['enrollNumber'], '12345');
      expect(map['macAddress'], 'AA:BB:CC:DD:EE:FF');
      expect(map['isPresent'], false);
    });

    test('Student toMap should exclude MAC address when null', () {
      final student = Student(
        id: 'test-id',
        name: 'Jane Doe',
        enrollNumber: '67890',
      );

      final map = student.toMap();
      expect(map['name'], 'Jane Doe');
      expect(map['enrollNumber'], '67890');
      expect(map.containsKey('macAddress'), false);
      expect(map['isPresent'], false);
    });
  });
}