import 'dart:typed_data';

class Person {
  final String name;
  final Uint8List templates;

  const Person({
    required this.name,
    required this.templates,
  });

  factory Person.fromMap(Map<String, dynamic> data) {
    return Person(
      name: data['name'],
      templates: data['templates'],
    );
  }

  Map<String, Object?> toMap() {
    var map = <String, Object?>{
      'name': name,
      'templates': templates,
    };
    return map;
  }
}
