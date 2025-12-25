// Stub file for web platform - provides File-like interface
// This is never actually used on web, but satisfies the compiler

class File {
  final String path;
  File(this.path);
  
  Future<bool> exists() async => false;
  Future<String> readAsString() async => '';
  Future<void> writeAsString(String contents) async {}
}

class Directory {
  final String path;
  Directory(this.path);
  
  Future<bool> exists() async => false;
  Future<void> create({bool recursive = false}) async {}
  List<File> listSync() => [];
}
