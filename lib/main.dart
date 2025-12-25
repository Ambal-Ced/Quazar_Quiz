import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';

// Conditional import for File - only on non-web platforms
import 'dart:io' if (dart.library.html) 'file_stub.dart' as io;
import 'package:path_provider/path_provider.dart';

void main() {
  runApp(const QuazarApp());
}

// Theme Preference Helper Functions
Future<void> _saveThemePreference(ThemeMode themeMode) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_mode', themeMode.toString().split('.').last);
  } catch (e) {
    // Handle error silently
  }
}

Future<ThemeMode> _loadThemePreference() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final themeString = prefs.getString('theme_mode');
    if (themeString == null) {
      return ThemeMode.dark; // Default to dark mode
    }
    switch (themeString) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
        return ThemeMode.system;
      default:
        return ThemeMode.dark;
    }
  } catch (e) {
    return ThemeMode.dark; // Default to dark mode on error
  }
}

// Quiz History Helper Functions
Future<List<Map<String, dynamic>>> _loadQuizHistory() async {
  try {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      final historyJson = prefs.getString('quiz_history');
      if (historyJson == null || historyJson.isEmpty) {
        print('Quiz history does not exist yet (web)');
        return [];
      }
      final List<dynamic> jsonData = json.decode(historyJson);
      final history = jsonData.cast<Map<String, dynamic>>();
      print('Loaded ${history.length} quiz history entries (web)');
      return history;
    } else {
      // Use file system for mobile/desktop
      return await _loadQuizHistoryFromFile();
    }
  } catch (e) {
    print('Error loading quiz history: $e');
    return [];
  }
}

// Platform-specific function for loading from file (non-web only)
Future<List<Map<String, dynamic>>> _loadQuizHistoryFromFile() async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/quiz_history.json';
    final file = io.File(path);
    
    if (!await file.exists()) {
      print('Quiz history file does not exist yet at: $path');
      return [];
    }
    
    final contents = await file.readAsString();
    if (contents.isEmpty) {
      print('Quiz history file is empty');
      return [];
    }
    
    final List<dynamic> jsonData = json.decode(contents);
    final history = jsonData.cast<Map<String, dynamic>>();
    print('Loaded ${history.length} quiz history entries');
    return history;
  } catch (e) {
    print('Error accessing file system: $e');
    return [];
  }
}

// Platform-specific function for saving to file (non-web only)
Future<void> _saveQuizHistoryToFile(List<Map<String, dynamic>> history) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final path = '${directory.path}/quiz_history.json';
    final file = io.File(path);
    
    // Ensure the directory exists
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    
    // Write the file
    await file.writeAsString(json.encode(history));
    
    // Verify the file was written
    if (await file.exists()) {
      print('Quiz history saved successfully to: $path');
    } else {
      print('Error: Quiz history file was not created at: $path');
    }
  } catch (e) {
    print('Error saving to file system: $e');
  }
}

Future<void> _saveQuizHistory(int score, int total, int percentage) async {
  try {
    final history = await _loadQuizHistory();
    final newEntry = {
      'id': DateTime.now().millisecondsSinceEpoch,
      'score': score,
      'total': total,
      'percentage': percentage,
      'date': DateTime.now().toIso8601String(),
    };
    
    history.insert(0, newEntry); // Add to beginning (most recent first)
    
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quiz_history', json.encode(history));
      print('Quiz history saved successfully (web)');
    } else {
      // Use file system for mobile/desktop
      await _saveQuizHistoryToFile(history);
    }
  } catch (e) {
    print('Error saving quiz history: $e');
    // Don't rethrow on web to prevent crashes
  }
}

// Clear quiz history function
Future<void> _clearQuizHistory() async {
  try {
    if (kIsWeb) {
      // Use SharedPreferences for web
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('quiz_history', json.encode([]));
      print('Quiz history cleared successfully (web)');
    } else {
      // Use file system for mobile/desktop
      await _saveQuizHistoryToFile([]);
    }
  } catch (e) {
    print('Error clearing quiz history: $e');
  }
}

// Validate JSON quiz file structure
bool _validateQuizJson(Map<String, dynamic> item) {
  // Check if all required fields exist (case-insensitive)
  final keys = item.keys.map((k) => k.toString().toLowerCase()).toSet();
  
  // Required fields: id, question(s), options, correctAnswer
  return keys.contains('id') && 
         (keys.contains('question') || keys.contains('questions')) &&
         keys.contains('options') &&
         (keys.contains('correctanswer') || keys.contains('correct_answer'));
}

// Format quiz name: capitalize all and replace special chars with spaces
String _formatQuizName(String fileName) {
  // Remove .json extension
  String name = fileName.replaceAll('.json', '');
  
  // Replace special characters with spaces
  name = name.replaceAll(RegExp(r'[^a-zA-Z0-9\s]'), ' ');
  
  // Capitalize all characters
  name = name.toUpperCase();
  
  // Clean up multiple spaces
  name = name.replaceAll(RegExp(r'\s+'), ' ').trim();
  
  return name;
}

// Get imported quizzes directory path
Future<String> _getImportedQuizzesDirectory() async {
  if (kIsWeb) {
    // Web doesn't support file system, use SharedPreferences
    return '';
  } else {
    final directory = await getApplicationDocumentsDirectory();
    return '${directory.path}/imported_quizzes';
  }
}

// Save imported quiz file
Future<String?> _saveImportedQuiz(String fileName, String content) async {
  try {
    if (kIsWeb) {
      // For web, save to SharedPreferences with a key
      final prefs = await SharedPreferences.getInstance();
      final importedQuizzes = prefs.getStringList('imported_quizzes') ?? [];
      final formattedName = _formatQuizName(fileName);
      
      // Save the quiz content
      await prefs.setString('quiz_$formattedName', content);
      
      // Add to list if not already present
      if (!importedQuizzes.contains(formattedName)) {
        importedQuizzes.add(formattedName);
        await prefs.setStringList('imported_quizzes', importedQuizzes);
      }
      
      return formattedName;
    } else {
      // For mobile/desktop, save to file system
      final directory = await _getImportedQuizzesDirectory();
      final dir = io.Directory(directory);
      
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      final formattedName = _formatQuizName(fileName);
      final file = io.File('$directory/$formattedName.json');
      await file.writeAsString(content);
      
      return formattedName;
    }
  } catch (e) {
    print('Error saving imported quiz: $e');
    return null;
  }
}

// Load imported quiz content
Future<String?> _loadImportedQuiz(String quizName) async {
  try {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString('quiz_$quizName');
    } else {
      final directory = await _getImportedQuizzesDirectory();
      final file = io.File('$directory/$quizName.json');
      
      if (await file.exists()) {
        return await file.readAsString();
      }
      return null;
    }
  } catch (e) {
    print('Error loading imported quiz: $e');
    return null;
  }
}

// Get list of imported quiz names
Future<List<String>> _getImportedQuizNames() async {
  try {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList('imported_quizzes') ?? [];
    } else {
      final directory = await _getImportedQuizzesDirectory();
      final dir = io.Directory(directory);
      
      if (!await dir.exists()) {
        return [];
      }
      
      final files = dir.listSync();
      return files
          .whereType<io.File>()
          .where((file) => file.path.endsWith('.json'))
          .map((file) {
            final pathParts = file.path.split(RegExp(r'[/\\]'));
            final fileName = pathParts.last.replaceAll('.json', '');
            return fileName;
          })
          .toList();
    }
  } catch (e) {
    print('Error getting imported quiz names: $e');
    return [];
  }
}

// Import quiz data from file
Future<bool> _importQuizData(BuildContext context) async {
  try {
    FilePickerResult? result;
    
    if (kIsWeb) {
      // Web file picker
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    } else {
      // Mobile/Desktop file picker
      result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
    }
    
    if (result == null || result.files.isEmpty) {
      return false; // User cancelled
    }
    
    String? fileContent;
    String fileName = result.files.single.name;
    
    if (kIsWeb) {
      // On web, read from bytes
      if (result.files.single.bytes != null) {
        fileContent = utf8.decode(result.files.single.bytes!);
      }
    } else {
      // On mobile/desktop, read from path
      if (result.files.single.path != null) {
        final file = io.File(result.files.single.path!);
        fileContent = await file.readAsString();
      }
    }
    
    if (fileContent == null || fileContent.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to read file content')),
        );
      }
      return false;
    }
    
    // Parse and validate JSON
    final jsonData = json.decode(fileContent);
    
    if (jsonData is! List || jsonData.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid JSON format. Expected an array of quiz items.')),
        );
      }
      return false;
    }
    
    // Validate each item in the array
    for (var item in jsonData) {
      if (item is! Map<String, dynamic>) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid JSON structure. Each item must be an object.')),
          );
        }
        return false;
      }
      
      if (!_validateQuizJson(item)) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invalid quiz format. Required fields: id, question(s), options, correctAnswer')),
          );
        }
        return false;
      }
    }
    
    // Save the imported quiz
    final savedName = await _saveImportedQuiz(fileName, fileContent);
    
    if (savedName == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save imported quiz')),
        );
      }
      return false;
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Quiz "$savedName" imported successfully!')),
      );
    }
    
    return true;
  } catch (e) {
    print('Error importing quiz: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error importing quiz: $e')),
      );
    }
    return false;
  }
}

class QuazarApp extends StatefulWidget {
  const QuazarApp({super.key});

  @override
  State<QuazarApp> createState() => _QuazarAppState();
}

class _QuazarAppState extends State<QuazarApp> {
  ThemeMode _themeMode = ThemeMode.dark; // Default to dark mode (black & gold)
  bool _isLoadingTheme = true;

  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    final savedTheme = await _loadThemePreference();
    setState(() {
      _themeMode = savedTheme;
      _isLoadingTheme = false;
    });
  }

  void _toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark
          ? ThemeMode.light
          : ThemeMode.dark;
    });
    // Save theme preference
    await _saveThemePreference(_themeMode);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while theme is being loaded
    if (_isLoadingTheme) {
    return MaterialApp(
        title: 'Quazar Quiz',
        debugShowCheckedModeBanner: false,
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.dark(
            primary: const Color(0xFFFFD700),
            background: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.black,
        ),
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MaterialApp(
      title: 'Quazar Quiz',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      // Light Theme: White and Dark Blue
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.light(
          primary: const Color(0xFF1565C0), // Dark Blue
          secondary: const Color(0xFF0D47A1), // Darker Blue
          surface: Colors.white,
          background: const Color(0xFFF5F5F5), // Light gray background
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: const Color(0xFF212121), // Dark text on white
          onBackground: const Color(0xFF212121),
          primaryContainer: const Color(0xFFE3F2FD), // Light blue container
          secondaryContainer: const Color(0xFFBBDEFB), // Lighter blue container
        ),
        scaffoldBackgroundColor: const Color(0xFFF5F5F5),
      ),
      // Dark Theme: Black and Gold
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: const Color(0xFFFFD700), // Gold
          secondary: const Color(0xFFFFC107), // Amber Gold
          surface: const Color(0xFF1A1A1A), // Dark gray surface
          background: Colors.black,
          onPrimary: Colors.black,
          onSecondary: Colors.black,
          onSurface: Colors.white,
          onBackground: Colors.white,
          primaryContainer: const Color(0xFF2A2A2A), // Dark container
          secondaryContainer: const Color(0xFF1F1F1F), // Darker container
        ),
        scaffoldBackgroundColor: Colors.black,
      ),
      home: LoadingScreen(
        onThemeToggle: _toggleTheme,
        isDarkMode: _themeMode == ThemeMode.dark,
      ),
    );
  }
}

class LoadingScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const LoadingScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  String _loadingText = 'Initializing...';
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    try {
      // Step 1: Loading app assets
      setState(() {
        _loadingText = 'Loading app assets...';
        _progress = 0.1;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 2: Loading quiz databases
    setState(() {
        _loadingText = 'Scanning quiz databases...';
        _progress = 0.3;
      });
      await _scanQuizFiles();

      // Step 3: Preparing quiz data
      setState(() {
        _loadingText = 'Preparing quiz data...';
        _progress = 0.6;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      // Step 4: Finalizing
      setState(() {
        _loadingText = 'Finalizing...';
        _progress = 0.9;
      });
      await Future.delayed(const Duration(milliseconds: 200));

      // Step 5: Complete
      setState(() {
        _loadingText = 'Ready!';
        _progress = 1.0;
      });
      await Future.delayed(const Duration(milliseconds: 300));

      // Navigate to login screen
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              onThemeToggle: widget.onThemeToggle,
              isDarkMode: widget.isDarkMode,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadingText = 'Error loading assets: $e';
        });
        // Still navigate after a delay even if there's an error
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => LoginScreen(
                onThemeToggle: widget.onThemeToggle,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _scanQuizFiles() async {
    // Scan for quiz files to preload them
    final knownFiles = ['quiz_data.json'];
    final commonNames = [
      'quiz_data.json',
      'questions.json',
      'quiz.json',
      'data.json',
    ];

    for (final fileName in [...knownFiles, ...commonNames]) {
      try {
        final assetPath = 'assets/$fileName';
        await rootBundle.loadString(assetPath);
      } catch (e) {
        // File doesn't exist, skip it
        continue;
      }
    }
  }

  Widget _buildFooter(bool isDark) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Opacity(
        opacity: 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Created By: Justine Cedrick Ambal',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Version: 2.11.4',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Key code: 2vAf56L',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: Stack(
          children: [
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
              // App Logo
              Container(
                width: 200,
                height: 200,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                        .withOpacity(0.5),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                          .withOpacity(0.3),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.asset(
                    'assets/appcon.webp',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback to PNG if webp fails
                      return Image.asset(
                        'assets/appcon.png',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          // Final fallback to icon if both images fail
                          return Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFFFFD700).withOpacity(0.2)
                                  : const Color(0xFF1565C0).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Icon(
                              Icons.quiz,
                              size: 60,
                              color: isDark
                                  ? const Color(0xFFFFD700)
                                  : const Color(0xFF1565C0),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 32),
              // App Title
              Text(
                'Quazar Quiz',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1565C0),
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 48),
              // Loading Indicator
              SizedBox(
                width: 50,
                height: 50,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              // Loading Text
              Text(
                _loadingText,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark
                      ? Colors.white70
                      : const Color(0xFF424242),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 16),
              // Progress Bar (optional, subtle)
              Container(
                width: 200,
                height: 2,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(1),
                  color: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: _progress,
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(1),
                      color: isDark
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const LoginScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isLoading = false;

  Widget _buildFooter(bool isDark) {
    return Positioned(
      bottom: 16,
      right: 16,
      child: Opacity(
        opacity: 0.4,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Created By: Justine Cedrick Ambal',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Version: 2.11.4',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Text(
              'Key code: 2vAf56L',
              style: TextStyle(
                fontSize: 10,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleStart() {
      setState(() {
        _isLoading = true;
      });

      // Simulate a brief loading delay for better UX
      Future.delayed(const Duration(milliseconds: 500), () {
      // Navigate to home screen
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                onThemeToggle: widget.onThemeToggle,
                isDarkMode: widget.isDarkMode,
              ),
            ),
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    // Dark theme: Black to dark gray gradient
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    // Light theme: White to light blue gradient
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // App Logo/Icon - Box Shape
                        Center(
                          child: Container(
                            width: 200,
                            height: 200,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                                    .withOpacity(0.5),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                                      .withOpacity(0.3),
                                  blurRadius: 20,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(18),
                              child: Image.asset(
                                'assets/appcon.webp',
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/appcon.png',
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.contain,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(
                                        Icons.quiz,
                                        size: 80,
                                        color: isDark
                                            ? const Color(0xFFFFD700)
                                            : const Color(0xFF1565C0),
                                      );
                                    },
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // App Title
                        Text(
                          'Quazar',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? const Color(0xFFFFD700) // Gold
                                    : const Color(0xFF1565C0), // Dark blue
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Quiz App',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF424242),
                              ),
                        ),
                        const SizedBox(height: 48),
                      // Start Button
                        ElevatedButton(
                        onPressed: _isLoading ? null : _handleStart,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            backgroundColor: isDark
                                ? const Color(0xFFFFD700) // Gold
                                : const Color(0xFF1565C0), // Dark blue
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.black : Colors.white,
                                    ),
                                  ),
                                )
                              : const Text(
                                'Start',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                        ),
                      ],
                  ),
                ),
              ),
              // Theme Toggle Button (top right, always on its own line)
              _buildFooter(isDark),
            ],
          ),
        ),
      ),
    );
  }
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;

  const HomeScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _passAttempts = 0;
  int _totalScore = 0;
  List<Map<String, dynamic>> _quizHistory = [];

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _loadQuizHistory();
    setState(() {
      _quizHistory = history;
      // Update pass attempts and total score based on history
      _passAttempts = history.length;
      _totalScore = history.fold<int>(
        0,
        (sum, entry) => sum + (entry['score'] as int? ?? 0),
      );
    });
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Main Content
              SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
                child: _buildHomeContent(context, isDark),
              ),
              // Floating theme toggle to keep it clickable
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: widget.onThemeToggle,
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(10),
                      child: Icon(
                        isDark ? Icons.light_mode : Icons.dark_mode,
                        color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeContent(BuildContext context, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Container(
            width: 200,
            height: 200,
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                    .withOpacity(0.5),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0))
                      .withOpacity(0.3),
                  blurRadius: 20,
                  spreadRadius: 5,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                'assets/appcon.webp',
                width: 200,
                height: 200,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Image.asset(
                  'assets/appcon.png',
                  width: 200,
                  height: 200,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: isDark
                        ? const Color(0xFFFFD700).withOpacity(0.2)
                        : const Color(0xFF1565C0).withOpacity(0.2),
                    child: Icon(
                      Icons.quiz,
                      size: 80,
                      color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        Text(
          'Quazar Quiz',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
              ),
        ),
        const SizedBox(height: 48),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                context,
                'Pass Attempts',
                '$_passAttempts',
                Icons.assignment_turned_in,
                isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildStatCard(
                context,
                'Total Score',
                '$_totalScore',
                Icons.star,
                isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => QuizSelectionScreen(
                  onThemeToggle: widget.onThemeToggle,
                  isDarkMode: widget.isDarkMode,
                  onQuizComplete: (score) {
                    setState(() {
                      _passAttempts++;
                      _totalScore += score;
                    });
                  },
                ),
              ),
            );
            _loadHistory();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 20),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            backgroundColor:
                isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
            foregroundColor: isDark ? Colors.black : Colors.white,
            elevation: 4,
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_arrow, size: 28),
              SizedBox(width: 8),
              Text(
                'Select Quiz',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Quiz History',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
              ),
            ),
            if (_quizHistory.isNotEmpty)
              TextButton.icon(
                onPressed: () async {
                  final shouldClear = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(
                        'Clear Quiz History',
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to clear all quiz history? This action cannot be undone.',
                        style: TextStyle(
                          color: isDark ? Colors.white70 : Colors.black87,
                        ),
                      ),
                      backgroundColor:
                          isDark ? const Color(0xFF2A2A2A) : Colors.white,
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          style: TextButton.styleFrom(foregroundColor: Colors.red),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );

                  if (shouldClear == true) {
                    await _clearQuizHistory();
                    _loadHistory();
                    if (mounted) {
                      setState(() {
                        _passAttempts = _quizHistory.length;
                        _totalScore = _quizHistory.fold<int>(
                          0,
                          (sum, entry) => sum + (entry['score'] as int? ?? 0),
                        );
                      });
                    }
                  }
                },
                icon: Icon(
                  Icons.delete_outline,
                  size: 18,
                  color: isDark ? Colors.red.withOpacity(0.8) : Colors.red,
                ),
                label: Text(
                  'Clear',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.red.withOpacity(0.8) : Colors.red,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (_quizHistory.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2A2A2A).withOpacity(0.7)
                  : Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? const Color(0xFFFFD700).withOpacity(0.3)
                    : const Color(0xFF1565C0).withOpacity(0.3),
              ),
            ),
            child: Text(
              'No quiz history yet. Complete a quiz to see your results here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
          ),
        if (_quizHistory.isNotEmpty)
          ..._quizHistory
              .map<Widget>((entry) => _buildHistoryTile(entry, isDark))
              .toList(),
      ],
    );
  }

  Widget _buildHistoryTile(Map<String, dynamic> entry, bool isDark) {
    final score = entry['score'] as int? ?? 0;
    final total = entry['total'] as int? ?? 0;
    final percentage = entry['percentage'] as int? ?? 0;
    final dateStr = entry['date'] as String? ?? '';

    DateTime? date;
    if (dateStr.isNotEmpty) {
      try {
        date = DateTime.parse(dateStr);
      } catch (_) {
        date = null;
      }
    }

    String formattedDate = '';
    if (date != null) {
      formattedDate =
          '${date.month}/${date.day}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2A2A2A).withOpacity(0.7) : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF1565C0).withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Score: $score / $total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
                ),
              ),
              if (formattedDate.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFFFFD700).withOpacity(0.2)
                  : const Color(0xFF1565C0).withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A).withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF1565C0).withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 40,
            color: isDark
                ? const Color(0xFFFFD700)
                : const Color(0xFF1565C0),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1565C0),
                ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: isDark
                      ? Colors.white70
                      : Colors.black54,
                ),
          ),
        ],
      ),
    );
  }
}

class QuizSelectionScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final Function(int) onQuizComplete;

  const QuizSelectionScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onQuizComplete,
  });

  @override
  State<QuizSelectionScreen> createState() => _QuizSelectionScreenState();
}

class _QuizSelectionScreenState extends State<QuizSelectionScreen> {
  List<Map<String, dynamic>> _availableQuizzes = [];

  @override
  void initState() {
    super.initState();
    _loadAvailableQuizzes();
  }

  Future<void> _loadAvailableQuizzes() async {
    // Scan for all JSON files in assets folder
    final List<Map<String, dynamic>> quizFiles = [];
    final Set<String> addedPaths = {}; // Track already added files
    
    // Known JSON files in assets folder - add new ones here as you add them
    final knownFiles = [
      'quiz_data.json',
      // Add more JSON files here as you add them to assets folder
      // Example: 'another_quiz.json',
    ];
    
    // Try to load each known file to verify it exists and get question count
    for (final fileName in knownFiles) {
      try {
        final assetPath = 'assets/$fileName';
        if (addedPaths.contains(assetPath)) continue;
        
        final String jsonString = await rootBundle.loadString(assetPath);
        final List<dynamic> jsonData = json.decode(jsonString);
        
        // Validate it's a quiz data structure (array of objects with question/answer)
        if (jsonData is List && jsonData.isNotEmpty) {
          final firstItem = jsonData[0];
          if (firstItem is Map && 
              (firstItem.containsKey('question') || firstItem.containsKey('Question'))) {
            // Extract name from filename (remove .json and format)
            String displayName = fileName
                .replaceAll('.json', '')
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) => word.isEmpty 
                    ? '' 
                    : word[0].toUpperCase() + word.substring(1))
                .join(' ');
            
            quizFiles.add({
              'name': displayName,
              'path': assetPath,
              'description': '${jsonData.length} questions available',
            });
            addedPaths.add(assetPath);
          }
        }
      } catch (e) {
        // File doesn't exist or is invalid, skip it
        continue;
      }
    }
    
    // Also try to discover JSON files dynamically by checking common patterns
    // This is a fallback for files not in the knownFiles list
    final commonNames = [
      'quiz_data.json',
      'questions.json',
      'quiz.json',
      'data.json',
      'quiz1.json',
      'quiz2.json',
      'test.json',
    ];
    
    for (final fileName in commonNames) {
      final assetPath = 'assets/$fileName';
      // Skip if already added
      if (addedPaths.contains(assetPath)) {
        continue;
      }
      
      try {
        final String jsonString = await rootBundle.loadString(assetPath);
        final List<dynamic> jsonData = json.decode(jsonString);
        
        // Validate it's a quiz data structure
        if (jsonData is List && jsonData.isNotEmpty) {
          final firstItem = jsonData[0];
          if (firstItem is Map && 
              (firstItem.containsKey('question') || firstItem.containsKey('Question'))) {
            String displayName = fileName
                .replaceAll('.json', '')
                .replaceAll('_', ' ')
                .split(' ')
                .map((word) => word.isEmpty 
                    ? '' 
                    : word[0].toUpperCase() + word.substring(1))
                .join(' ');
            
            quizFiles.add({
              'name': displayName,
              'path': assetPath,
              'description': '${jsonData.length} questions available',
            });
            addedPaths.add(assetPath);
          }
        }
      } catch (e) {
        // File doesn't exist, skip it
        continue;
      }
    }

    // Load imported quizzes
    final importedQuizNames = await _getImportedQuizNames();
    for (final quizName in importedQuizNames) {
      try {
        final quizContent = await _loadImportedQuiz(quizName);
        if (quizContent != null) {
          final List<dynamic> jsonData = json.decode(quizContent);
          
          if (jsonData is List && jsonData.isNotEmpty) {
            quizFiles.add({
              'name': quizName,
              'path': 'imported:$quizName', // Special marker for imported quizzes
              'description': '${jsonData.length} questions available',
            });
          }
        }
      } catch (e) {
        print('Error loading imported quiz $quizName: $e');
        continue;
      }
    }

    setState(() {
      _availableQuizzes = quizFiles;
    });
  }

  Future<void> _loadQuizData(String assetPath, String quizName) async {
    try {
      String jsonString;
      
      // Check if it's an imported quiz
      if (assetPath.startsWith('imported:')) {
        final importedName = assetPath.replaceFirst('imported:', '');
        final quizContent = await _loadImportedQuiz(importedName);
        if (quizContent == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed to load quiz: $quizName')),
            );
          }
          return;
        }
        jsonString = quizContent;
      } else {
        // Load from assets
        jsonString = await rootBundle.loadString(assetPath);
      }
      
      final List<dynamic> jsonData = json.decode(jsonString);
      
      if (mounted) {
        // Navigate to quiz settings screen
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => QuizSettingsScreen(
              onThemeToggle: widget.onThemeToggle,
              isDarkMode: widget.isDarkMode,
              quizData: jsonData.cast<Map<String, dynamic>>(),
              quizName: quizName,
              assetPath: assetPath,
              onQuizComplete: widget.onQuizComplete,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading quiz: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Quiz Database'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE3F2FD),
        foregroundColor: isDark
            ? const Color(0xFFFFD700)
            : const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline),
            tooltip: 'Add Quiz Data',
            onPressed: () async {
              final success = await _importQuizData(context);
              if (success && mounted) {
                // Reload quizzes to include the newly imported one
                _loadAvailableQuizzes();
              }
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: _availableQuizzes.isEmpty
            ? const Center(
                child: CircularProgressIndicator(),
              )
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _availableQuizzes.length,
                itemBuilder: (context, index) {
                  final quiz = _availableQuizzes[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    color: isDark
                        ? const Color(0xFF2A2A2A).withOpacity(0.7)
                        : Colors.white.withOpacity(0.9),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFFFFD700).withOpacity(0.3)
                            : const Color(0xFF1565C0).withOpacity(0.3),
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(20),
                      title: Text(
                        quiz['name'],
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1565C0),
                        ),
                      ),
                      subtitle: Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          quiz['description'],
                          style: TextStyle(
                            color: isDark
                                ? Colors.white70
                                : Colors.black54,
                          ),
                        ),
                      ),
                      trailing: Icon(
                        Icons.arrow_forward_ios,
                        color: isDark
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF1565C0),
                      ),
                      onTap: () => _loadQuizData(quiz['path'], quiz['name']),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class TableQuestionConfigScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final bool initialWithOptions;
  final List<String> initialJsonFiles;
  final List<String> initialJsonFileNames;
  final Function(bool withOptions, List<String> jsonFilePaths, List<String> jsonFileNames) onConfigComplete;

  const TableQuestionConfigScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.initialWithOptions,
    required this.initialJsonFiles,
    required this.initialJsonFileNames,
    required this.onConfigComplete,
  });

  @override
  State<TableQuestionConfigScreen> createState() => _TableQuestionConfigScreenState();
}

class _TableQuestionConfigScreenState extends State<TableQuestionConfigScreen> {
  bool _withOptions = false;
  List<String> _selectedJsonFilePaths = [];
  List<String> _selectedJsonFileNames = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _withOptions = widget.initialWithOptions;
    _selectedJsonFilePaths = List<String>.from(widget.initialJsonFiles);
    _selectedJsonFileNames = List<String>.from(widget.initialJsonFileNames);
  }

  Future<void> _selectJsonFiles() async {
    try {
      FilePickerResult? result;
      
      if (kIsWeb) {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          allowMultiple: true,
        );
      } else {
        result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['json'],
          allowMultiple: true,
        );
      }
      
      if (result == null || result.files.isEmpty) {
        return; // User cancelled
      }
      
      setState(() {
        _isLoading = true;
      });
      
      final List<String> newFilePaths = [];
      final List<String> newFileNames = [];
      
      for (final file in result.files) {
        String? filePath;
        String fileName = file.name;
        
        // Check if file is already selected
        if (_selectedJsonFileNames.contains(fileName)) {
          continue; // Skip already selected files
        }
        
        if (kIsWeb) {
          // On web, we'll store the file name and read content later
          filePath = 'imported:$fileName';
        } else {
          // On mobile/desktop, use the file path
          filePath = file.path;
        }
        
        // Validate it's a table JSON file
        String? fileContent;
        if (kIsWeb) {
          if (file.bytes != null) {
            fileContent = utf8.decode(file.bytes!);
          }
        } else {
          if (file.path != null) {
            final fileObj = io.File(file.path!);
            fileContent = await fileObj.readAsString();
          }
        }
        
        if (fileContent != null) {
          try {
            final jsonData = json.decode(fileContent);
            if (jsonData is List && jsonData.isNotEmpty) {
              final firstItem = jsonData[0];
              if (firstItem is Map && firstItem.containsKey('quizType') && 
                  firstItem['quizType'] == 'fillInTheBlankTable') {
                newFilePaths.add(filePath!);
                newFileNames.add(fileName);
                
                // Save file content for later use
                if (!kIsWeb && file.path != null) {
                  // On mobile/desktop, we can use the path directly
                } else {
                  // On web, save to shared preferences
                  await _saveImportedTableFile(fileName, fileContent);
                  newFilePaths[newFilePaths.length - 1] = 'imported:$fileName';
                }
              } else {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('$fileName: Invalid table JSON file. File must contain table questions.'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            } else {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('$fileName: Invalid JSON format. Expected an array.'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('$fileName: Error parsing JSON: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        }
      }
      
      setState(() {
        _selectedJsonFilePaths.addAll(newFilePaths);
        _selectedJsonFileNames.addAll(newFileNames);
        _isLoading = false;
      });
      
      if (newFilePaths.isNotEmpty && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added ${newFilePaths.length} file(s)'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error selecting files: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  void _removeFile(int index) {
    setState(() {
      _selectedJsonFilePaths.removeAt(index);
      _selectedJsonFileNames.removeAt(index);
    });
  }

  Future<void> _saveImportedTableFile(String fileName, String content) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('imported_table_$fileName', content);
    } catch (e) {
      // Handle error
    }
  }

  void _confirm() {
    if (_selectedJsonFilePaths.isEmpty || _selectedJsonFileNames.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one JSON file'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    
    widget.onConfigComplete(_withOptions, _selectedJsonFilePaths, _selectedJsonFileNames);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Table Question Configuration'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE3F2FD),
        foregroundColor: isDark
            ? const Color(0xFFFFD700)
            : const Color(0xFF1565C0),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, const Color(0xFF1A1A1A)]
                : [Colors.white, const Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Configure Table Questions',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 32),
                // Option type selection
                Text(
                  'Answer Type',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 16),
                _buildCheckboxOption(
                  context,
                  'With options',
                  'Users can select from given options (scrambled correct answers)',
                  _withOptions,
                  (value) {
                    setState(() {
                      _withOptions = value;
                    });
                  },
                  isDark,
                ),
                const SizedBox(height: 12),
                _buildCheckboxOption(
                  context,
                  'Without options',
                  'Users need to type in the answer',
                  !_withOptions,
                  (value) {
                    setState(() {
                      _withOptions = !value;
                    });
                  },
                  isDark,
                ),
                const SizedBox(height: 32),
                // JSON file selection
                Text(
                  'Table JSON Files',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _selectJsonFiles,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.file_upload),
                  label: Text(_selectedJsonFileNames.isEmpty 
                      ? 'Select JSON Files' 
                      : 'Add More Files (${_selectedJsonFileNames.length} selected)'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                    foregroundColor: isDark ? Colors.black : Colors.white,
                  ),
                ),
                if (_selectedJsonFileNames.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ...List.generate(_selectedJsonFileNames.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedJsonFileNames[index],
                                style: const TextStyle(color: Colors.green),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () => _removeFile(index),
                              tooltip: 'Remove file',
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
                const SizedBox(height: 40),
                // Confirm button
                ElevatedButton(
                  onPressed: _selectedJsonFilePaths.isNotEmpty ? _confirm : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    backgroundColor: _selectedJsonFilePaths.isNotEmpty
                        ? (isDark
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF1565C0))
                        : Colors.grey,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                  ),
                  child: const Text(
                    'Confirm',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(
    BuildContext context,
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A).withOpacity(0.5)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF1565C0).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: isDark
                ? const Color(0xFFFFD700)
                : const Color(0xFF1565C0),
            checkColor: isDark ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class QuizSettingsScreen extends StatefulWidget {
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final List<Map<String, dynamic>> quizData;
  final String quizName;
  final String assetPath;
  final Function(int) onQuizComplete;

  const QuizSettingsScreen({
    super.key,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.quizData,
    required this.quizName,
    required this.assetPath,
    required this.onQuizComplete,
  });

  @override
  State<QuizSettingsScreen> createState() => _QuizSettingsScreenState();
}

class _QuizSettingsScreenState extends State<QuizSettingsScreen> {
  final _questionCountController = TextEditingController();
  final _multipleChoiceCountController = TextEditingController();
  final _identificationCountController = TextEditingController();
  final _trueOrFalseCountController = TextEditingController();
  int _totalQuestions = 0;
  int _availableQuestions = 0;
  bool _uniqueAnswerOnly = false;
  bool _multipleChoice = false;
  bool _identification = false;
  bool _trueOrFalse = false;
  bool _fillInTheBlankTable = false;
  bool _tableWithOptions = false; // true = With options, false = Without options
  List<String> _tableJsonFilePaths = []; // Paths to the selected table JSON files
  List<String> _tableJsonFileNames = []; // Names of the selected table JSON files
  String? _questionCountError;
  String? _multipleChoiceError;
  String? _identificationError;
  String? _trueOrFalseError;

  @override
  void initState() {
    super.initState();
    _totalQuestions = widget.quizData.length;
    _availableQuestions = _totalQuestions;
    _questionCountController.text = _totalQuestions.toString();
    _questionCountController.addListener(_validateQuestionCount);
    _questionCountController.addListener(_redistributeTypeQuestions);
    _multipleChoiceCountController.addListener(_validateTypeCounts);
    _identificationCountController.addListener(_validateTypeCounts);
    _trueOrFalseCountController.addListener(_validateTypeCounts);
  }

  @override
  void dispose() {
    _questionCountController.dispose();
    _multipleChoiceCountController.dispose();
    _identificationCountController.dispose();
    _trueOrFalseCountController.dispose();
    super.dispose();
  }

  void _validateQuestionCount() {
    final text = _questionCountController.text;
    if (text.isEmpty) {
      setState(() {
        _questionCountError = 'Please enter a number';
      });
      return;
    }

    final count = int.tryParse(text);
    if (count == null) {
      setState(() {
        _questionCountError = 'Please enter a valid number';
      });
      return;
    }

    if (count <= 0) {
      setState(() {
        _questionCountError = 'Must be greater than 0';
      });
      return;
    }

    if (count > _availableQuestions) {
      setState(() {
        _questionCountError = 'Cannot exceed $_availableQuestions questions';
      });
      return;
    }

    setState(() {
      _questionCountError = null;
    });
  }

  void _updateAvailableQuestions() {
    List<Map<String, dynamic>> filteredData = List.from(widget.quizData);

    if (_uniqueAnswerOnly) {
      // Filter to keep only one question per unique answer
      // Special handling: True/False answers are treated as unique per question
      Map<String, Map<String, dynamic>> uniqueAnswers = {};
      int trueFalseCounter = 0; // Counter to make True/False answers unique
      
      for (var question in filteredData) {
        final answer = question['correctAnswer']?.toString().toLowerCase().trim() ?? '';
        if (answer.isEmpty) continue;
        
        // Check if answer is "true" or "false"
        final isTrueFalse = answer == 'true' || answer == 'false';
        
        String uniqueKey;
        if (isTrueFalse) {
          // For True/False, each question is unique (use question ID or index)
          uniqueKey = '${answer}_${question['id'] ?? trueFalseCounter++}';
        } else {
          // For other answers, use the answer itself as the key
          uniqueKey = answer;
        }
        
        if (!uniqueAnswers.containsKey(uniqueKey)) {
          uniqueAnswers[uniqueKey] = question;
        }
      }
      filteredData = uniqueAnswers.values.toList();
    }

    setState(() {
      _availableQuestions = filteredData.length;
      if (int.tryParse(_questionCountController.text) != null) {
        final currentCount = int.parse(_questionCountController.text);
        if (currentCount > _availableQuestions) {
          _questionCountController.text = _availableQuestions.toString();
        }
      } else {
        _questionCountController.text = _availableQuestions.toString();
      }
      _validateQuestionCount();
      _redistributeTypeQuestions();
    });
  }

  int _getEnabledTypeCount() {
    int count = 0;
    if (_multipleChoice) count++;
    if (_identification) count++;
    if (_trueOrFalse) count++;
    if (_fillInTheBlankTable) count++;
    return count;
  }

  void _redistributeTypeQuestions() {
    final enabledCount = _getEnabledTypeCount();
    if (enabledCount == 0) {
      _multipleChoiceCountController.text = '';
      _identificationCountController.text = '';
      _trueOrFalseCountController.text = '';
      return;
    }

    final totalText = _questionCountController.text;
    final total = int.tryParse(totalText);
    if (total == null || total <= 0) return;

    final perType = total ~/ enabledCount;
    final remainder = total % enabledCount;

    // Distribute questions equally, with remainder going to first enabled type
    int distributed = 0;
    if (_multipleChoice) {
      final count = perType + (distributed < remainder ? 1 : 0);
      _multipleChoiceCountController.text = count.toString();
      distributed += count;
    } else {
      _multipleChoiceCountController.text = '';
    }

    if (_identification) {
      final count = perType + (distributed < remainder ? 1 : 0);
      _identificationCountController.text = count.toString();
      distributed += count;
    } else {
      _identificationCountController.text = '';
    }

    if (_trueOrFalse) {
      final count = perType + (distributed < remainder ? 1 : 0);
      _trueOrFalseCountController.text = count.toString();
      distributed += count;
    } else {
      _trueOrFalseCountController.text = '';
    }

    _validateTypeCounts();
  }

  void _validateTypeCounts() {
    final enabledCount = _getEnabledTypeCount();
    if (enabledCount == 0) {
      setState(() {
        _multipleChoiceError = null;
        _identificationError = null;
        _trueOrFalseError = null;
      });
      return;
    }

    final totalText = _questionCountController.text;
    final total = int.tryParse(totalText);
    if (total == null) return;

    int sum = 0;
    String? mcError, idError, tfError;

    if (_multipleChoice) {
      final mcText = _multipleChoiceCountController.text;
      if (mcText.isEmpty) {
        mcError = 'Required';
      } else {
        final mcCount = int.tryParse(mcText);
        if (mcCount == null) {
          mcError = 'Invalid number';
        } else if (mcCount <= 0) {
          mcError = 'Must be > 0';
        } else {
          sum += mcCount;
        }
      }
    }

    if (_identification) {
      final idText = _identificationCountController.text;
      if (idText.isEmpty) {
        idError = 'Required';
      } else {
        final idCount = int.tryParse(idText);
        if (idCount == null) {
          idError = 'Invalid number';
        } else if (idCount <= 0) {
          idError = 'Must be > 0';
        } else {
          sum += idCount;
        }
      }
    }

    if (_trueOrFalse) {
      final tfText = _trueOrFalseCountController.text;
      if (tfText.isEmpty) {
        tfError = 'Required';
      } else {
        final tfCount = int.tryParse(tfText);
        if (tfCount == null) {
          tfError = 'Invalid number';
        } else if (tfCount <= 0) {
          tfError = 'Must be > 0';
        } else {
          sum += tfCount;
        }
      }
    }

    // Check if sum equals total
    if (sum != total && mcError == null && idError == null && tfError == null) {
      final errorMsg = 'Sum must equal $total (currently $sum)';
      if (_multipleChoice && mcError == null) mcError = errorMsg;
      if (_identification && idError == null && mcError == null) idError = errorMsg;
      if (_trueOrFalse && tfError == null && mcError == null && idError == null) tfError = errorMsg;
    }

    setState(() {
      _multipleChoiceError = mcError;
      _identificationError = idError;
      _trueOrFalseError = tfError;
    });
  }

  Future<void> _loadTableQuestions(List<Map<String, dynamic>> quizQuestions) async {
    try {
      for (int i = 0; i < _tableJsonFilePaths.length; i++) {
        final filePath = _tableJsonFilePaths[i];
        String? jsonString;
        
        if (filePath.startsWith('imported:')) {
          // Load from shared preferences
          final prefs = await SharedPreferences.getInstance();
          final fileName = filePath.replaceFirst('imported:', '');
          jsonString = prefs.getString('imported_table_$fileName');
        } else {
          // Load from file path (mobile/desktop)
          final file = io.File(filePath);
          jsonString = await file.readAsString();
        }
        
        if (jsonString == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to load table JSON file: ${_tableJsonFileNames[i]}'),
                backgroundColor: Colors.red,
              ),
            );
          }
          continue;
        }
        
        final List<dynamic> tableData = json.decode(jsonString);
        
        for (var table in tableData) {
          if (table is Map<String, dynamic> && 
              table['quizType'] == 'fillInTheBlankTable') {
            quizQuestions.add({
              ...table,
              'withOptions': _tableWithOptions,
            });
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading table questions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _startQuiz() async {
    // Check if at least one quiz type is selected
    final enabledCount = _getEnabledTypeCount();
    if (enabledCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select at least one quiz type'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_questionCountError != null || _questionCountController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please fix the errors before starting'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (enabledCount > 0) {
      // Validate type counts
      if (_multipleChoiceError != null || 
          _identificationError != null || 
          _trueOrFalseError != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please fix the question type errors'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Validate sum equals total
      int sum = 0;
      if (_multipleChoice) {
        sum += int.tryParse(_multipleChoiceCountController.text) ?? 0;
      }
      if (_identification) {
        sum += int.tryParse(_identificationCountController.text) ?? 0;
      }
      if (_trueOrFalse) {
        sum += int.tryParse(_trueOrFalseCountController.text) ?? 0;
      }

      final questionCount = int.parse(_questionCountController.text);
      if (sum != questionCount) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Question type counts must sum to $questionCount (currently $sum)'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }

    final questionCount = int.parse(_questionCountController.text);
    if (questionCount > _availableQuestions) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cannot exceed $_availableQuestions questions'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Filter questions based on settings
    List<Map<String, dynamic>> filteredData = List.from(widget.quizData);

    if (_uniqueAnswerOnly) {
      // Filter to keep only one question per unique answer
      // Special handling: True/False answers are treated as unique per question
      Map<String, Map<String, dynamic>> uniqueAnswers = {};
      int trueFalseCounter = 0; // Counter to make True/False answers unique
      
      for (var question in filteredData) {
        final answer = question['correctAnswer']?.toString().toLowerCase().trim() ?? '';
        if (answer.isEmpty) continue;
        
        // Check if answer is "true" or "false"
        final isTrueFalse = answer == 'true' || answer == 'false';
        
        String uniqueKey;
        if (isTrueFalse) {
          // For True/False, each question is unique (use question ID or index)
          uniqueKey = '${answer}_${question['id'] ?? trueFalseCounter++}';
        } else {
          // For other answers, use the answer itself as the key
          uniqueKey = answer;
        }
        
        if (!uniqueAnswers.containsKey(uniqueKey)) {
          uniqueAnswers[uniqueKey] = question;
        }
      }
      filteredData = uniqueAnswers.values.toList();
    }

    // Prepare questions based on quiz types
    List<Map<String, dynamic>> quizQuestions = [];
    
    // Get all available answers for wrong answer generation
    List<String> allAnswers = widget.quizData
        .map((q) => q['correctAnswer']?.toString().trim() ?? '')
        .where((a) => a.isNotEmpty)
        .toList();
    
    // Shuffle all questions first
    filteredData.shuffle();
    
    // Distribute questions by type
    int mcCount = _multipleChoice ? int.parse(_multipleChoiceCountController.text) : 0;
    int idCount = _identification ? int.parse(_identificationCountController.text) : 0;
    int tfCount = _trueOrFalse ? int.parse(_trueOrFalseCountController.text) : 0;
    
    int currentIndex = 0;
    
    // Add Multiple Choice questions
    for (int i = 0; i < mcCount && currentIndex < filteredData.length; i++) {
      quizQuestions.add({
        ...filteredData[currentIndex],
        'quizType': 'multipleChoice',
      });
      currentIndex++;
    }
    
    // Add Identification questions
    for (int i = 0; i < idCount && currentIndex < filteredData.length; i++) {
      quizQuestions.add({
        ...filteredData[currentIndex],
        'quizType': 'identification',
      });
      currentIndex++;
    }
    
    // Add True/False questions
    for (int i = 0; i < tfCount && currentIndex < filteredData.length; i++) {
      quizQuestions.add({
        ...filteredData[currentIndex],
        'quizType': 'trueOrFalse',
      });
      currentIndex++;
    }
    
    // Load and add Table questions if enabled
    if (_fillInTheBlankTable && _tableJsonFilePaths.isNotEmpty) {
      await _loadTableQuestions(quizQuestions);
    }
    
    // Shuffle the final question list
    quizQuestions.shuffle();

    // Navigate to quiz screen
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => QuizScreen(
            questions: quizQuestions,
            allAnswers: allAnswers,
            onThemeToggle: widget.onThemeToggle,
            isDarkMode: widget.isDarkMode,
            onQuizComplete: widget.onQuizComplete,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Settings'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE3F2FD),
        foregroundColor: isDark
            ? const Color(0xFFFFD700)
            : const Color(0xFF1565C0),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 72, 24, 24),
        child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              // Quiz Info Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2A2A2A).withOpacity(0.7)
                      : Colors.white.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFFFFD700).withOpacity(0.3)
                        : const Color(0xFF1565C0).withOpacity(0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      widget.quizName,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF1565C0),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildInfoItem(
                          context,
                          'Total Questions',
                          '$_totalQuestions',
                          Icons.help_outline,
                          isDark,
                        ),
                        _buildInfoItem(
                          context,
                          'Available',
                          '$_availableQuestions',
                          Icons.check_circle_outline,
                          isDark,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              // Question Count Input
              Text(
                'Number of Questions',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _questionCountController,
                keyboardType: TextInputType.number,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 18,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter number of questions',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  errorText: _questionCountError,
                  prefixIcon: Icon(
                    Icons.numbers,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFFFFD700).withOpacity(0.5)
                          : const Color(0xFF1565C0).withOpacity(0.5),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFFFFD700).withOpacity(0.3)
                          : const Color(0xFF1565C0).withOpacity(0.3),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: isDark
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1565C0),
                      width: 2,
                    ),
                  ),
                  filled: true,
                  fillColor: isDark
                      ? const Color(0xFF2A2A2A).withOpacity(0.5)
                      : Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              // Quiz Type Options
              Text(
                'Quiz Type',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1565C0),
                ),
              ),
              const SizedBox(height: 16),
              _buildCheckboxOption(
                context,
                'Unique Answer Only',
                'Filter questions to show only one per unique answer',
                _uniqueAnswerOnly,
                (value) {
                  setState(() {
                    _uniqueAnswerOnly = value;
                  });
                  _updateAvailableQuestions();
                },
                isDark,
              ),
              const SizedBox(height: 12),
              _buildCheckboxOption(
                context,
                'Multiple Choice',
                'Questions will be displayed as multiple choice',
                _multipleChoice,
                (value) {
                  setState(() {
                    _multipleChoice = value;
                  });
                  _redistributeTypeQuestions();
                },
                isDark,
              ),
              if (_multipleChoice) ...[
                const SizedBox(height: 8),
                _buildTypeCountField(
                  context,
                  'Multiple Choice Questions',
                  _multipleChoiceCountController,
                  _multipleChoiceError,
                  isDark,
                ),
              ],
              const SizedBox(height: 12),
              _buildCheckboxOption(
                context,
                'Identification',
                'Questions will require text input answers',
                _identification,
                (value) {
                  setState(() {
                    _identification = value;
                  });
                  _redistributeTypeQuestions();
                },
                isDark,
              ),
              if (_identification) ...[
                const SizedBox(height: 8),
                _buildTypeCountField(
                  context,
                  'Identification Questions',
                  _identificationCountController,
                  _identificationError,
                  isDark,
                ),
              ],
              const SizedBox(height: 12),
              _buildCheckboxOption(
                context,
                'True or False',
                'Questions will be displayed as true/false',
                _trueOrFalse,
                (value) {
                  setState(() {
                    _trueOrFalse = value;
                  });
                  _redistributeTypeQuestions();
                },
                isDark,
              ),
              if (_trueOrFalse) ...[
                const SizedBox(height: 8),
                _buildTypeCountField(
                  context,
                  'True or False Questions',
                  _trueOrFalseCountController,
                  _trueOrFalseError,
                  isDark,
                ),
              ],
              const SizedBox(height: 12),
              _buildCheckboxOption(
                context,
                'Fill in the Blank (Table Type)',
                'Questions will be displayed as a table with blanks to fill',
                _fillInTheBlankTable,
                (value) {
                  setState(() {
                    _fillInTheBlankTable = value;
                    if (value) {
                      // Navigate to table configuration screen
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => TableQuestionConfigScreen(
                            onThemeToggle: widget.onThemeToggle,
                            isDarkMode: widget.isDarkMode,
                            initialWithOptions: _tableWithOptions,
                            initialJsonFiles: _tableJsonFilePaths,
                            initialJsonFileNames: _tableJsonFileNames,
                            onConfigComplete: (withOptions, jsonFilePaths, jsonFileNames) {
                              setState(() {
                                _tableWithOptions = withOptions;
                                _tableJsonFilePaths = jsonFilePaths;
                                _tableJsonFileNames = jsonFileNames;
                              });
                            },
                          ),
                        ),
                      );
                    } else {
                      _tableWithOptions = false;
                      _tableJsonFilePaths = [];
                      _tableJsonFileNames = [];
                    }
                  });
                  _redistributeTypeQuestions();
                },
                isDark,
              ),
              if (_fillInTheBlankTable && _tableJsonFileNames.isNotEmpty) ...[
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.only(left: 16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A).withOpacity(0.5)
                          : Colors.white.withOpacity(0.7),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFFFFD700).withOpacity(0.3)
                            : const Color(0xFF1565C0).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Table Config: ${_tableWithOptions ? "With Options" : "Without Options"}',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark ? Colors.white : Colors.black87,
                                ),
                              ),
                              Text(
                                'Files: ${_tableJsonFileNames.length} file(s)',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.white70 : Colors.black54,
                                ),
                              ),
                              if (_tableJsonFileNames.length <= 3)
                                ..._tableJsonFileNames.map((fileName) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• $fileName',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                )).toList(),
                              if (_tableJsonFileNames.length > 3)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    '• ${_tableJsonFileNames.take(3).join('\n• ')}\n• ... and ${_tableJsonFileNames.length - 3} more',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.white60 : Colors.black45,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            // Navigate to table configuration screen again
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => TableQuestionConfigScreen(
                                  onThemeToggle: widget.onThemeToggle,
                                  isDarkMode: widget.isDarkMode,
                                  initialWithOptions: _tableWithOptions,
                                  initialJsonFiles: _tableJsonFilePaths,
                                  initialJsonFileNames: _tableJsonFileNames,
                                  onConfigComplete: (withOptions, jsonFilePaths, jsonFileNames) {
                                    setState(() {
                                      _tableWithOptions = withOptions;
                                      _tableJsonFilePaths = jsonFilePaths;
                                      _tableJsonFileNames = jsonFileNames;
                                    });
                                  },
                                ),
                              ),
                            );
                          },
                          child: Text('Edit'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 40),
              // Start Quiz Button
              ElevatedButton(
                onPressed: _getEnabledTypeCount() > 0 ? _startQuiz : null,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  backgroundColor: _getEnabledTypeCount() > 0
                      ? (isDark
                          ? const Color(0xFFFFD700)
                          : const Color(0xFF1565C0))
                      : (isDark
                          ? Colors.grey.shade800
                          : Colors.grey.shade300),
                  foregroundColor: _getEnabledTypeCount() > 0
                      ? (isDark
                          ? Colors.black
                          : Colors.white)
                      : (isDark
                          ? Colors.grey.shade600
                          : Colors.grey.shade600),
                  elevation: _getEnabledTypeCount() > 0 ? 4 : 0,
                  disabledBackgroundColor: isDark
                      ? Colors.grey.shade800
                      : Colors.grey.shade300,
                ),
                child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_arrow,
                      size: 28,
                      color: _getEnabledTypeCount() > 0
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade600),
                    ),
                    const SizedBox(width: 8),
            Text(
                      _getEnabledTypeCount() > 0
                          ? 'Start Quiz'
                          : 'Select a Quiz Type',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: _getEnabledTypeCount() > 0
                            ? (isDark ? Colors.black : Colors.white)
                            : (isDark
                                ? Colors.grey.shade600
                                : Colors.grey.shade600),
                      ),
            ),
          ],
        ),
      ),
            ],
          ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: widget.onThemeToggle,
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: 48,
                    height: 48,
                    padding: const EdgeInsets.all(10),
                    child: Icon(
                      isDark ? Icons.light_mode : Icons.dark_mode,
                      color: isDark ? const Color(0xFFFFD700) : const Color(0xFF1565C0),
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    bool isDark,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          color: isDark
              ? const Color(0xFFFFD700)
              : const Color(0xFF1565C0),
          size: 32,
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: isDark
                ? const Color(0xFFFFD700)
                : const Color(0xFF1565C0),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark
                ? Colors.white70
                : Colors.black54,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckboxOption(
    BuildContext context,
    String title,
    String description,
    bool value,
    Function(bool) onChanged,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A).withOpacity(0.5)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF1565C0).withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Checkbox(
            value: value,
            onChanged: (newValue) => onChanged(newValue ?? false),
            activeColor: isDark
                ? const Color(0xFFFFD700)
                : const Color(0xFF1565C0),
            checkColor: isDark ? Colors.black : Colors.white,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeCountField(
    BuildContext context,
    String label,
    TextEditingController controller,
    String? error,
    bool isDark,
  ) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
        ),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
          ),
          hintText: 'Enter number of questions',
          hintStyle: TextStyle(
            color: isDark ? Colors.white38 : Colors.black38,
          ),
          errorText: error,
          prefixIcon: Icon(
            Icons.numbers,
            color: isDark
                ? const Color(0xFFFFD700)
                : const Color(0xFF1565C0),
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFFFFD700).withOpacity(0.5)
                  : const Color(0xFF1565C0).withOpacity(0.5),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFFFFD700).withOpacity(0.3)
                  : const Color(0xFF1565C0).withOpacity(0.3),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: isDark
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF1565C0),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: isDark
              ? const Color(0xFF2A2A2A).withOpacity(0.3)
              : Colors.white.withOpacity(0.5),
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final List<Map<String, dynamic>> questions;
  final List<String> allAnswers;
  final VoidCallback onThemeToggle;
  final bool isDarkMode;
  final Function(int) onQuizComplete;

  const QuizScreen({
    super.key,
    required this.questions,
    required this.allAnswers,
    required this.onThemeToggle,
    required this.isDarkMode,
    required this.onQuizComplete,
  });

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Grouped questions by type
  List<Map<String, dynamic>> _multipleChoiceQuestions = [];
  List<Map<String, dynamic>> _identificationQuestions = [];
  List<Map<String, dynamic>> _trueOrFalseQuestions = [];
  List<Map<String, dynamic>> _fillInTheBlankTableQuestions = [];
  
  // Current state
  String _currentSection = ''; // 'multipleChoice', 'identification', 'trueOrFalse', 'fillInTheBlankTable', 'loading', 'results'
  int _currentSectionQuestionIndex = 0;
  int _currentGlobalIndex = 0;
  bool _sectionStarted = false; // Track if section title screen has been dismissed
  
  // Answers and results
  Map<int, String?> _userAnswers = {}; // Global index -> answer
  Map<int, bool> _isCorrect = {}; // Global index -> isCorrect
  Map<int, String> _correctAnswers = {}; // Global index -> correct answer
  List<String> _multipleChoiceOptions = [];
  Map<int, String?> _trueFalseDisplayedAnswers = {}; // Global index -> displayed answer
  
  // Table question state
  Map<int, Map<String, String>> _tableUserAnswers = {}; // Global index -> {cell_key: user_answer}
  Map<int, String?> _selectedTableCell = {}; // Global index -> selected cell key (for with options mode)
  Map<int, List<String>> _tableOptions = {}; // Global index -> list of options (for with options mode)
  
  String? _selectedAnswer;
  final TextEditingController _identificationController = TextEditingController();
  final TextEditingController _trueFalseController = TextEditingController();
  final Map<String, TextEditingController> _tableCellControllers = {}; // cell_key -> controller
  bool _isLoading = false;
  int _loadingProgress = 0;
  bool _showResult = false;

  @override
  void initState() {
    super.initState();
    _organizeQuestions();
    _prepareTrueFalseQuestions();
    _startFirstSection();
  }

  @override
  void dispose() {
    _identificationController.dispose();
    _trueFalseController.dispose();
    for (var controller in _tableCellControllers.values) {
      controller.dispose();
    }
    _tableCellControllers.clear();
    super.dispose();
  }

  void _organizeQuestions() {
    int globalIndex = 0;
    for (var question in widget.questions) {
      final quizType = question['quizType'] as String?;
      _correctAnswers[globalIndex] = question['correctAnswer']?.toString().trim() ?? '';
      
      if (quizType == 'multipleChoice') {
        _multipleChoiceQuestions.add({...question, 'globalIndex': globalIndex});
      } else if (quizType == 'identification') {
        _identificationQuestions.add({...question, 'globalIndex': globalIndex});
      } else if (quizType == 'trueOrFalse') {
        _trueOrFalseQuestions.add({...question, 'globalIndex': globalIndex});
      } else if (quizType == 'fillInTheBlankTable') {
        _fillInTheBlankTableQuestions.add({...question, 'globalIndex': globalIndex});
        // Initialize table answer storage
        _tableUserAnswers[globalIndex] = {};
        // Generate options if needed (for "with options" mode)
        _generateTableOptions(question, globalIndex);
      }
      globalIndex++;
    }
  }

  void _generateTableOptions(Map<String, dynamic> question, int globalIndex) {
    // Extract all answers from the table (without cell references)
    final answers = question['answers'] as Map<String, dynamic>? ?? {};
    
    final options = <String>[];
    
    // Add correct answers
    answers.forEach((cellKey, answer) {
      if (answer != null && answer.toString().trim().isNotEmpty) {
        // Just add the answer text, no cell reference
        final answerText = answer.toString().trim();
        if (!options.contains(answerText)) {
          options.add(answerText);
        }
      }
    });
    
    // Add wrong options (from cells with ^ prefix)
    final wrongOptions = question['wrongOptions'] as List<dynamic>? ?? [];
    for (var wrongOption in wrongOptions) {
      if (wrongOption != null && wrongOption.toString().trim().isNotEmpty) {
        final wrongOptionText = wrongOption.toString().trim();
        if (!options.contains(wrongOptionText)) {
          options.add(wrongOptionText);
        }
      }
    }
    
    // Shuffle and store options
    options.shuffle();
    _tableOptions[globalIndex] = options;
  }

  void _prepareTrueFalseQuestions() {
    // Prepare True/False questions by randomizing displayed answers
    for (var question in _trueOrFalseQuestions) {
      final globalIndex = question['globalIndex'] as int;
      final correctAnswer = question['correctAnswer']?.toString().trim() ?? '';
      if (correctAnswer.isEmpty) continue;

      // Check if question has preferred choices in options array
      final preferredOptions = question['options'] as List<dynamic>?;
      if (preferredOptions != null && preferredOptions.isNotEmpty) {
        // Use preferred choices - randomly select one (can be correct or wrong)
        final validOptions = <String>[];
        for (final option in preferredOptions) {
          final optionStr = option?.toString().trim() ?? '';
          if (optionStr.isNotEmpty) {
            validOptions.add(optionStr);
          }
        }
        
        if (validOptions.isNotEmpty) {
          // Randomly select from preferred options
          final random = DateTime.now().millisecondsSinceEpoch + globalIndex;
          final selectedIndex = random % validOptions.length;
          _trueFalseDisplayedAnswers[globalIndex] = validOptions[selectedIndex];
        } else {
          // Fallback to correct answer if no valid options
          _trueFalseDisplayedAnswers[globalIndex] = correctAnswer;
        }
      } else {
        // No preferred choices - use original logic
        final random = DateTime.now().millisecondsSinceEpoch + globalIndex;
        final showCorrect = random % 2 == 0;
        
        if (showCorrect) {
          _trueFalseDisplayedAnswers[globalIndex] = correctAnswer;
        } else {
          List<String> wrongAnswers = widget.allAnswers
              .where((answer) => 
                  answer.toLowerCase().trim() != correctAnswer.toLowerCase().trim())
              .toList();
          
          if (wrongAnswers.isNotEmpty) {
            wrongAnswers.shuffle();
            _trueFalseDisplayedAnswers[globalIndex] = wrongAnswers[0];
          } else {
            _trueFalseDisplayedAnswers[globalIndex] = correctAnswer;
          }
        }
      }
    }
  }

  void _startFirstSection() {
    if (_multipleChoiceQuestions.isNotEmpty) {
      setState(() {
        _currentSection = 'multipleChoice';
        _currentSectionQuestionIndex = 0;
        _currentGlobalIndex = _multipleChoiceQuestions[0]['globalIndex'] as int;
        _sectionStarted = false; // Show section title first
      });
      _loadCurrentQuestion();
    } else if (_identificationQuestions.isNotEmpty) {
      setState(() {
        _currentSection = 'identification';
        _currentSectionQuestionIndex = 0;
        _currentGlobalIndex = _identificationQuestions[0]['globalIndex'] as int;
        _sectionStarted = false; // Show section title first
      });
      _loadCurrentQuestion();
    } else if (_trueOrFalseQuestions.isNotEmpty) {
      setState(() {
        _currentSection = 'trueOrFalse';
        _currentSectionQuestionIndex = 0;
        _currentGlobalIndex = _trueOrFalseQuestions[0]['globalIndex'] as int;
        _sectionStarted = false; // Show section title first
      });
      _loadCurrentQuestion();
    } else if (_fillInTheBlankTableQuestions.isNotEmpty) {
      setState(() {
        _currentSection = 'fillInTheBlankTable';
        _currentSectionQuestionIndex = 0;
        _currentGlobalIndex = _fillInTheBlankTableQuestions[0]['globalIndex'] as int;
        _sectionStarted = false; // Show section title first
      });
      _loadCurrentQuestion();
    }
  }

  void _loadCurrentQuestion() {
    Map<String, dynamic> question;
    if (_currentSection == 'multipleChoice') {
      question = _multipleChoiceQuestions[_currentSectionQuestionIndex];
    } else if (_currentSection == 'identification') {
      question = _identificationQuestions[_currentSectionQuestionIndex];
    } else if (_currentSection == 'trueOrFalse') {
      question = _trueOrFalseQuestions[_currentSectionQuestionIndex];
    } else if (_currentSection == 'fillInTheBlankTable') {
      question = _fillInTheBlankTableQuestions[_currentSectionQuestionIndex];
      // Initialize controllers for table cells
      _initializeTableControllers(question);
    } else {
      question = _trueOrFalseQuestions[_currentSectionQuestionIndex];
    }

    if (_currentSection == 'multipleChoice') {
      _generateMultipleChoiceOptions(question);
    } else {
      _selectedAnswer = _userAnswers[_currentGlobalIndex];
      _multipleChoiceOptions = [];
      if (_currentSection == 'identification') {
        _identificationController.text = _selectedAnswer ?? '';
      } else if (_currentSection == 'trueOrFalse') {
        _trueFalseController.text = _selectedAnswer ?? '';
      }
    }
  }

  void _initializeTableControllers(Map<String, dynamic> question) {
    final tableData = question['tableData'] as Map<String, dynamic>?;
    if (tableData == null) return;
    
    final rows = (tableData['rows'] as List<dynamic>?) ?? [];
    final userAnswers = _tableUserAnswers[_currentGlobalIndex] ?? {};
    
    for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
      final row = rows[rowIdx] as Map<String, dynamic>;
      final cells = (row['cells'] as List<dynamic>?) ?? [];
      
      for (int colIdx = 0; colIdx < cells.length; colIdx++) {
        final cell = cells[colIdx] as Map<String, dynamic>;
        if (cell['type'] == 'blank') {
          final cellKey = '${rowIdx}_${colIdx}';
          if (!_tableCellControllers.containsKey(cellKey)) {
            _tableCellControllers[cellKey] = TextEditingController();
          }
          _tableCellControllers[cellKey]!.text = userAnswers[cellKey] ?? '';
        }
      }
    }
  }

  Map<String, dynamic> _getCurrentQuestion() {
    if (_currentSection == 'multipleChoice') {
      return _multipleChoiceQuestions[_currentSectionQuestionIndex];
    } else if (_currentSection == 'identification') {
      return _identificationQuestions[_currentSectionQuestionIndex];
    } else if (_currentSection == 'fillInTheBlankTable') {
      return _fillInTheBlankTableQuestions[_currentSectionQuestionIndex];
    } else {
      return _trueOrFalseQuestions[_currentSectionQuestionIndex];
    }
  }

  int _getCurrentSectionTotal() {
    if (_currentSection == 'multipleChoice') {
      return _multipleChoiceQuestions.length;
    } else if (_currentSection == 'identification') {
      return _identificationQuestions.length;
    } else if (_currentSection == 'fillInTheBlankTable') {
      return _fillInTheBlankTableQuestions.length;
    } else {
      return _trueOrFalseQuestions.length;
    }
  }

  bool _isLastQuestionInSection() {
    return _currentSectionQuestionIndex >= _getCurrentSectionTotal() - 1;
  }

  bool _isLastQuestionOverall() {
    if (_currentSection == 'multipleChoice') {
      return _isLastQuestionInSection() && 
             _identificationQuestions.isEmpty && 
             _trueOrFalseQuestions.isEmpty &&
             _fillInTheBlankTableQuestions.isEmpty;
    } else if (_currentSection == 'identification') {
      return _isLastQuestionInSection() && 
             _trueOrFalseQuestions.isEmpty &&
             _fillInTheBlankTableQuestions.isEmpty;
    } else if (_currentSection == 'trueOrFalse') {
      return _isLastQuestionInSection() && 
             _fillInTheBlankTableQuestions.isEmpty;
    } else if (_currentSection == 'fillInTheBlankTable') {
      return _isLastQuestionInSection();
    } else {
      return _isLastQuestionInSection();
    }
  }

  void _generateMultipleChoiceOptions(Map<String, dynamic> question) {
    final correctAnswer = question['correctAnswer']?.toString().trim() ?? '';
    if (correctAnswer.isEmpty) {
      _multipleChoiceOptions = [];
      return;
    }
    final normalizedCorrect = _normalizeForComparison(correctAnswer);
    if (normalizedCorrect.isEmpty) {
      _multipleChoiceOptions = [];
      return;
    }

    // Check if question has preferred choices in options array
    final preferredOptions = question['options'] as List<dynamic>?;
    if (preferredOptions != null && preferredOptions.isNotEmpty) {
      // Use preferred choices as options
      final options = <String>[];
      void addOption(String value) {
        if (value.trim().isEmpty) return;
        if (!_answerListContains(options, value)) {
          options.add(value.trim());
        }
      }

      // Add all preferred options
      for (final option in preferredOptions) {
        final optionStr = option?.toString().trim() ?? '';
        if (optionStr.isNotEmpty) {
          addOption(optionStr);
        }
      }

      // Ensure correct answer is included
      addOption(correctAnswer);

      // Fill up to 4 options if needed (but only if we have less than 4)
      if (options.length < 4) {
        // Collect unique wrong answers from all answers
        final seenAnswers = <String>{};
        for (final opt in options) {
          seenAnswers.add(_normalizeForComparison(opt));
        }
        
        final uniqueWrongAnswers = <String>[];
        for (final answer in widget.allAnswers) {
          final trimmed = answer.trim();
          if (trimmed.isEmpty) continue;
          final normalized = _normalizeForComparison(trimmed);
          if (normalized.isEmpty || seenAnswers.contains(normalized)) continue;
          seenAnswers.add(normalized);
          uniqueWrongAnswers.add(trimmed);
        }

        // Add wrong answers until we have 4 options
        uniqueWrongAnswers.shuffle();
        for (final answer in uniqueWrongAnswers) {
          if (options.length >= 4) break;
          addOption(answer);
        }
      }

      options.shuffle();
      setState(() {
        _multipleChoiceOptions = options;
      });
      return;
    }

    // Special case: If answer is True or False, only show True/False options
    if (normalizedCorrect == 'true' || normalizedCorrect == 'false') {
      List<String> options = ['True', 'False'];
      options.shuffle();
      setState(() {
        _multipleChoiceOptions = options;
      });
      return;
    }

    // Collect unique wrong answers
    final seenAnswers = <String>{normalizedCorrect};
    final uniqueWrongAnswers = <String>[];
    for (final answer in widget.allAnswers) {
      final trimmed = answer.trim();
      if (trimmed.isEmpty) continue;
      final normalized = _normalizeForComparison(trimmed);
      if (normalized.isEmpty || seenAnswers.contains(normalized)) continue;
      seenAnswers.add(normalized);
      uniqueWrongAnswers.add(trimmed);
    }

    if (uniqueWrongAnswers.isEmpty) {
      // Fallback to only the correct answer if we cannot build options
      setState(() {
        _multipleChoiceOptions = [correctAnswer];
      });
      return;
    }

    final scoredWrongAnswers = uniqueWrongAnswers
        .map((answer) => MapEntry(
              answer,
              _answerSimilarityScore(
                normalizedCorrect,
                _normalizeForComparison(answer),
              ),
            ))
        .toList();

    final similarAnswers =
        scoredWrongAnswers.where((entry) => entry.value > 0).toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final remainingAnswers =
        scoredWrongAnswers.where((entry) => entry.value == 0).map((e) => e.key).toList()
          ..shuffle();

    final selectedWrongAnswers = <String>[];
    for (final entry in similarAnswers) {
      if (selectedWrongAnswers.length >= 3) break;
      if (!_answerListContains(selectedWrongAnswers, entry.key)) {
        selectedWrongAnswers.add(entry.key);
      }
    }
    if (selectedWrongAnswers.length < 3) {
      remainingAnswers.shuffle();
      for (final answer in remainingAnswers) {
        if (selectedWrongAnswers.length >= 3) break;
        if (!_answerListContains(selectedWrongAnswers, answer)) {
          selectedWrongAnswers.add(answer);
        }
      }
    }

    if (selectedWrongAnswers.length < 3) {
      // Final fallback: re-use any remaining answers (even if already similar) without duplicates
      final fallbackPool = List<String>.from(widget.allAnswers)
        ..removeWhere(
          (answer) => _normalizeForComparison(answer) == normalizedCorrect,
        );
      fallbackPool.shuffle();
      for (final answer in fallbackPool) {
        if (selectedWrongAnswers.length >= 3) break;
        final trimmed = answer.trim();
        if (trimmed.isEmpty) continue;
        if (!_answerListContains(selectedWrongAnswers, trimmed)) {
          selectedWrongAnswers.add(trimmed);
        }
      }
    }

    if (selectedWrongAnswers.length < 3) {
      // As a last resort, synthesize variations of the correct answer
      const fillerSuffixes = [' value', ' data', ' field', ' hash'];
      for (final suffix in fillerSuffixes) {
        if (selectedWrongAnswers.length >= 3) break;
        final candidate = '$correctAnswer$suffix';
        if (_normalizeForComparison(candidate) == normalizedCorrect) continue;
        if (!_answerListContains(selectedWrongAnswers, candidate)) {
          selectedWrongAnswers.add(candidate);
        }
      }
    }

    final options = <String>[];
    void addOption(String value) {
      if (value.trim().isEmpty) return;
      if (!_answerListContains(options, value)) {
        options.add(value.trim());
      }
    }

    addOption(correctAnswer);
    for (final wrong in selectedWrongAnswers) {
      addOption(wrong);
    }

    if (options.length < 4) {
      const extraSuffixes = [' option', ' choice', ' entry'];
      for (final suffix in extraSuffixes) {
        if (options.length >= 4) break;
        final candidate = '$correctAnswer$suffix ${options.length}';
        addOption(candidate);
      }
    }

    options.shuffle();

    setState(() {
      _multipleChoiceOptions = options;
    });
  }

  void _selectAnswer(String answer) {
    setState(() {
      _selectedAnswer = answer;
    });
  }

  bool _canProceed() {
    if (_currentSection == 'multipleChoice') {
      // Must select one of the 4 options
      return _selectedAnswer != null && _selectedAnswer!.isNotEmpty;
    } else if (_currentSection == 'identification') {
      // Must type something in the text field
      return _identificationController.text.trim().isNotEmpty;
    } else if (_currentSection == 'trueOrFalse') {
      // Must type something in the text field
      return _trueFalseController.text.trim().isNotEmpty;
    } else if (_currentSection == 'fillInTheBlankTable') {
      // Check if all blank cells are filled
      final question = _getCurrentQuestion();
      final tableData = question['tableData'] as Map<String, dynamic>?;
      if (tableData == null) return false;
      
      final rows = (tableData['rows'] as List<dynamic>?) ?? [];
      final userAnswers = _tableUserAnswers[_currentGlobalIndex] ?? {};
      
      for (int rowIdx = 0; rowIdx < rows.length; rowIdx++) {
        final row = rows[rowIdx] as Map<String, dynamic>;
        final cells = (row['cells'] as List<dynamic>?) ?? [];
        
        for (int colIdx = 0; colIdx < cells.length; colIdx++) {
          final cell = cells[colIdx] as Map<String, dynamic>;
          if (cell['type'] == 'blank') {
            final cellKey = '${rowIdx}_${colIdx}';
            final answer = userAnswers[cellKey] ?? '';
            if (answer.trim().isEmpty) {
              return false;
            }
          }
        }
      }
      return true;
    }
    return false;
  }

  String _normalizeAnswer(String text) {
    if (text.isEmpty) return text;
    
    // Replace special characters with spaces
    String normalized = text.replaceAll(RegExp(r'[-_.,;:!?@#$%^&*()+=\[\]{}|\\/"<>~`]'), ' ');
    
    // Replace multiple spaces with single space
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    
    // Trim and capitalize words
    normalized = normalized.trim();
    if (normalized.isEmpty) return normalized;
    
    return normalized
        .split(' ')
        .map((word) => word.isEmpty
            ? ''
            : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  String _normalizeForComparison(String text) {
    if (text.isEmpty) return '';
    final cleaned = text
        .replaceAll(RegExp(r'[-_.,;:!?@#$%^&*()+=\[\]{}|\\/"<>~`0-9]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    return cleaned;
  }

  double _answerSimilarityScore(String target, String candidate) {
    if (target.isEmpty || candidate.isEmpty || target == candidate) {
      return 0;
    }

    double score = 0;

    // Shared substring / containment bonus
    if (candidate.contains(target) || target.contains(candidate)) {
      final shorter = target.length < candidate.length ? target.length : candidate.length;
      final longer = target.length > candidate.length ? target.length : candidate.length;
      score += 1 + (shorter / (longer == 0 ? 1 : longer));
    }

    // Shared words bonus
    final targetWords = target.split(' ').where((word) => word.isNotEmpty).toSet();
    final candidateWords = candidate.split(' ').where((word) => word.isNotEmpty).toSet();
    final sharedWords = targetWords.intersection(candidateWords);
    if (sharedWords.isNotEmpty) {
      score += sharedWords.length / (targetWords.length == 0 ? 1 : targetWords.length);
    }

    // Common prefix bonus (helps with similar beginnings)
    int prefixLen = 0;
    final minLength = target.length < candidate.length ? target.length : candidate.length;
    for (int i = 0; i < minLength; i++) {
      if (target[i] == candidate[i]) {
        prefixLen++;
      } else {
        break;
      }
    }
    if (prefixLen >= 3) {
      score += prefixLen / minLength;
    }

    return score;
  }

  bool _answerListContains(List<String> answers, String candidate) {
    final normalizedCandidate = _normalizeForComparison(candidate);
    if (normalizedCandidate.isEmpty) {
      return false;
    }
    return answers.any(
      (answer) => _normalizeForComparison(answer) == normalizedCandidate,
    );
  }

  void _submitAnswer() {
    // Get answer based on quiz type
    if (_currentSection == 'identification') {
      _selectedAnswer = _identificationController.text.trim();
    } else if (_currentSection == 'trueOrFalse') {
      _selectedAnswer = _trueFalseController.text.trim();
    } else if (_currentSection == 'fillInTheBlankTable') {
      // Validate all blanks are filled
      final question = _getCurrentQuestion();
      final tableData = question['tableData'] as Map<String, dynamic>?;
      if (tableData == null) return;
      
      final userAnswers = _tableUserAnswers[_currentGlobalIndex] ?? {};
      final answers = question['answers'] as Map<String, dynamic>? ?? {};
      
      // Check if all cells that have answers are filled
      bool allFilled = true;
      answers.forEach((cellKey, correctAnswer) {
        final userAnswer = userAnswers[cellKey] ?? '';
        if (userAnswer.trim().isEmpty) {
          allFilled = false;
        }
      });
      
      if (!allFilled) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please fill in all blank cells'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      
      // Validate answers - only check cells that have answers in the answers map
      int correctCount = 0;
      int totalBlanks = 0;
      
      // Only validate cells that have answers (blanks that need to be filled)
      answers.forEach((cellKey, correctAnswer) {
        totalBlanks++;
        final userAnswer = (userAnswers[cellKey] ?? '').trim().toLowerCase();
        final correctAnswerStr = (correctAnswer?.toString() ?? '').trim().toLowerCase();
        if (userAnswer == correctAnswerStr) {
          correctCount++;
        }
      });
      
      // Question is correct if all blanks are correct
      final isCorrect = totalBlanks > 0 && correctCount == totalBlanks;
      
      setState(() {
        _isCorrect[_currentGlobalIndex] = isCorrect;
      });
    }
    
    if (_currentSection != 'fillInTheBlankTable') {
    if (_selectedAnswer == null || _selectedAnswer!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_currentSection == 'multipleChoice' 
              ? 'Please select an answer'
              : 'Please enter an answer'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final question = _getCurrentQuestion();
    final quizType = _currentSection;
    
    String correctAnswer = question['correctAnswer']?.toString().trim() ?? '';
    String userAnswer = _selectedAnswer!.trim();
    bool isCorrect = false;
    
    if (quizType == 'identification') {
      correctAnswer = _normalizeAnswer(correctAnswer);
      userAnswer = _normalizeAnswer(userAnswer);
      isCorrect = userAnswer == correctAnswer;
    } else if (quizType == 'trueOrFalse') {
      final displayedAnswer = _trueFalseDisplayedAnswers[_currentGlobalIndex] ?? '';
      final displayedAnswerLower = displayedAnswer.toLowerCase().trim();
      final correctAnswerLower = correctAnswer.toLowerCase().trim();
      final statementIsTrue = displayedAnswerLower == correctAnswerLower;
      final userSelectedTrue = userAnswer.toLowerCase() == 'true';
      isCorrect = (statementIsTrue && userSelectedTrue) || (!statementIsTrue && !userSelectedTrue);
    } else {
      correctAnswer = correctAnswer.toLowerCase();
      userAnswer = userAnswer.toLowerCase();
      isCorrect = userAnswer == correctAnswer;
    }

    setState(() {
      _userAnswers[_currentGlobalIndex] = _selectedAnswer;
      _isCorrect[_currentGlobalIndex] = isCorrect;
    });
    }

    // Move to next question or next section
    if (_isLastQuestionOverall()) {
      // Start loading/grading
      _startGrading();
    } else if (_isLastQuestionInSection()) {
      // Move to next section
      _moveToNextSection();
    } else {
      // Move to next question in same section
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          setState(() {
            _currentSectionQuestionIndex++;
            if (_currentSection == 'multipleChoice') {
              _currentGlobalIndex = _multipleChoiceQuestions[_currentSectionQuestionIndex]['globalIndex'] as int;
            } else if (_currentSection == 'identification') {
              _currentGlobalIndex = _identificationQuestions[_currentSectionQuestionIndex]['globalIndex'] as int;
            } else if (_currentSection == 'fillInTheBlankTable') {
              _currentGlobalIndex = _fillInTheBlankTableQuestions[_currentSectionQuestionIndex]['globalIndex'] as int;
            } else {
              _currentGlobalIndex = _trueOrFalseQuestions[_currentSectionQuestionIndex]['globalIndex'] as int;
            }
            _selectedAnswer = _userAnswers[_currentGlobalIndex];
            _loadCurrentQuestion();
          });
        }
      });
    }
  }

  void _moveToNextSection() {
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        if (_currentSection == 'multipleChoice' && _identificationQuestions.isNotEmpty) {
          setState(() {
            _currentSection = 'identification';
            _currentSectionQuestionIndex = 0;
            _currentGlobalIndex = _identificationQuestions[0]['globalIndex'] as int;
            _selectedAnswer = _userAnswers[_currentGlobalIndex];
            _sectionStarted = false; // Reset flag for new section
            _loadCurrentQuestion();
          });
        } else if ((_currentSection == 'multipleChoice' || _currentSection == 'identification') && 
                   _trueOrFalseQuestions.isNotEmpty) {
          setState(() {
            _currentSection = 'trueOrFalse';
            _currentSectionQuestionIndex = 0;
            _currentGlobalIndex = _trueOrFalseQuestions[0]['globalIndex'] as int;
            _selectedAnswer = _userAnswers[_currentGlobalIndex];
            _sectionStarted = false; // Reset flag for new section
            _loadCurrentQuestion();
          });
        } else if ((_currentSection == 'multipleChoice' || _currentSection == 'identification' || 
                    _currentSection == 'trueOrFalse') && 
                   _fillInTheBlankTableQuestions.isNotEmpty) {
          setState(() {
            _currentSection = 'fillInTheBlankTable';
            _currentSectionQuestionIndex = 0;
            _currentGlobalIndex = _fillInTheBlankTableQuestions[0]['globalIndex'] as int;
            _sectionStarted = false; // Reset flag for new section
            _loadCurrentQuestion();
          });
        }
      }
    });
  }

  void _startGrading() {
    setState(() {
      _isLoading = true;
      _loadingProgress = 0;
      _currentSection = 'loading';
    });
    
    // Simulate grading process
    _simulateGrading();
  }

  Future<void> _simulateGrading() async {
    final totalQuestions = widget.questions.length;
    for (int i = 0; i < totalQuestions; i++) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (mounted) {
        setState(() {
          _loadingProgress = i + 1;
        });
      }
    }
    
    await Future.delayed(const Duration(milliseconds: 500));
    
    if (mounted) {
      // Save quiz history immediately after grading
      final score = _isCorrect.values.where((correct) => correct).length;
      final total = widget.questions.length;
      final percentage = total > 0 ? (score / total * 100).round() : 0;
      await _saveQuizHistory(score, total, percentage);
      
      setState(() {
        _isLoading = false;
        _showResult = true;
        _currentSection = 'results';
      });
    }
  }

  void _finishQuiz() async {
    // History is already saved in _simulateGrading, no need to save again
    final score = _isCorrect.values.where((correct) => correct).length;
    
    widget.onQuizComplete(score);
    
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_currentSection == 'loading') {
      return _buildLoadingScreen(isDark);
    }

    if (_currentSection == 'results' || _showResult) {
      return _buildDetailedResultScreen(isDark);
    }

    // Show section title if it's the first question of a section and section hasn't been started yet
    if (_currentSectionQuestionIndex == 0 && !_sectionStarted) {
      return _buildSectionTitleScreen(isDark);
    }

    return _buildQuestionScreen(isDark);
  }

  Widget _buildSectionTitleScreen(bool isDark) {
    String sectionTitle = '';
    int totalQuestions = 0;
    bool isTableQuiz = false;
    if (_currentSection == 'multipleChoice') {
      sectionTitle = 'Multiple Choice';
      totalQuestions = _multipleChoiceQuestions.length;
    } else if (_currentSection == 'identification') {
      sectionTitle = 'Identification';
      totalQuestions = _identificationQuestions.length;
    } else if (_currentSection == 'trueOrFalse') {
      sectionTitle = 'True or False';
      totalQuestions = _trueOrFalseQuestions.length;
    } else if (_currentSection == 'fillInTheBlankTable') {
      sectionTitle = 'Table Fill';
      totalQuestions = _fillInTheBlankTableQuestions.length;
      isTableQuiz = true;
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, const Color(0xFF1A1A1A)]
                : [Colors.white, const Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  sectionTitle,
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isTableQuiz 
                      ? '$totalQuestions ${totalQuestions == 1 ? 'table' : 'tables'}'
                      : '$totalQuestions ${totalQuestions == 1 ? 'question' : 'questions'}',
                  style: TextStyle(
                    fontSize: 18,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _currentSectionQuestionIndex = 0;
                      _sectionStarted = true; // Mark section as started
                    });
                    _loadCurrentQuestion();
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                    foregroundColor: isDark
                        ? Colors.black
                        : Colors.white,
                    elevation: 4,
                  ),
                  child: const Text(
                    'Start',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingScreen(bool isDark) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [Colors.black, const Color(0xFF1A1A1A)]
                : [Colors.white, const Color(0xFFE3F2FD)],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  'Checking your answer and grading it',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Question $_loadingProgress of ${widget.questions.length}',
                  style: TextStyle(
                    fontSize: 16,
                    color: isDark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuestionScreen(bool isDark) {
    final question = _getCurrentQuestion();
    final quizType = _currentSection;
    String questionText = question['question']?.toString() ?? '';
    
    // For table questions, always show "Fill in the Table"
    if (quizType == 'fillInTheBlankTable') {
      questionText = 'Fill in the Table';
    }
    // For identification with True/False answer, prepend the prefix
    else if (quizType == 'identification') {
      final correctAnswer = question['correctAnswer']?.toString().trim().toLowerCase() ?? '';
      if (correctAnswer == 'true' || correctAnswer == 'false') {
        questionText = 'Does the statement tells the truth? : $questionText';
      }
    }
    // For True/False, format as: True/False = question (if answer is True/False) or displayedAnswer = question
    else if (quizType == 'trueOrFalse') {
      final correctAnswer = question['correctAnswer']?.toString().trim().toLowerCase() ?? '';
      if (correctAnswer == 'true' || correctAnswer == 'false') {
        // If correct answer is True/False, use it directly
        questionText = '${correctAnswer[0].toUpperCase() + correctAnswer.substring(1)} = $questionText';
      } else {
        // Otherwise use the displayed answer (randomized)
        final displayedAnswer = _trueFalseDisplayedAnswers[_currentGlobalIndex] ?? '';
        if (displayedAnswer.isNotEmpty) {
          questionText = '$displayedAnswer = $questionText';
        }
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${_currentSectionQuestionIndex + 1} of ${_getCurrentSectionTotal()}'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE3F2FD),
        foregroundColor: isDark
            ? const Color(0xFFFFD700)
            : const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Progress indicator
                LinearProgressIndicator(
                  value: (_currentSectionQuestionIndex + 1) / _getCurrentSectionTotal(),
                  backgroundColor: isDark
                      ? Colors.white.withOpacity(0.1)
                      : Colors.black.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 32),
                // Question
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A).withOpacity(0.7)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFFD700).withOpacity(0.3)
                          : const Color(0xFF1565C0).withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    questionText,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Answer options based on quiz type
                if (_currentSection == 'multipleChoice') ...[
                  ..._multipleChoiceOptions.asMap().entries.map((entry) {
                    final index = entry.key;
                    final option = entry.value;
                    final letter = String.fromCharCode(65 + index); // A, B, C, D
                    final isSelected = _selectedAnswer == option;
                    
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: InkWell(
                        onTap: () => _selectAnswer(option),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? (isDark
                                    ? const Color(0xFFFFD700).withOpacity(0.3)
                                    : const Color(0xFF1565C0).withOpacity(0.3))
                                : (isDark
                                    ? const Color(0xFF2A2A2A).withOpacity(0.5)
                                    : Colors.white.withOpacity(0.7)),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? (isDark
                                      ? const Color(0xFFFFD700)
                                      : const Color(0xFF1565C0))
                                  : (isDark
                                      ? const Color(0xFFFFD700).withOpacity(0.3)
                                      : const Color(0xFF1565C0).withOpacity(0.3)),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? (isDark
                                          ? const Color(0xFFFFD700)
                                          : const Color(0xFF1565C0))
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: isSelected
                                        ? (isDark
                                            ? const Color(0xFFFFD700)
                                            : const Color(0xFF1565C0))
                                        : (isDark
                                            ? Colors.white.withOpacity(0.3)
                                            : Colors.black.withOpacity(0.3)),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    letter,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? (isDark ? Colors.black : Colors.white)
                                          : (isDark ? Colors.white70 : Colors.black54),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: isDark ? Colors.white : Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ] else if (_currentSection == 'fillInTheBlankTable') ...[
                  _buildTableQuestion(question, isDark),
                ] else if (_currentSection == 'identification') ...[
                  TextField(
                    controller: _identificationController,
                    onChanged: (value) {
                      setState(() {
                        _selectedAnswer = value;
                      });
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Enter your answer',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      hintText: 'Type your answer here',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFFFFD700).withOpacity(0.3)
                              : const Color(0xFF1565C0).withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1565C0),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A2A).withOpacity(0.5)
                          : Colors.white,
                    ),
                  ),
                ] else if (_currentSection == 'trueOrFalse') ...[
                  TextField(
                    controller: _trueFalseController,
                    onChanged: (value) {
                      setState(() {
                        _selectedAnswer = value;
                      });
                    },
                    style: TextStyle(
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Enter True or False',
                      labelStyle: TextStyle(
                        color: isDark ? Colors.white70 : Colors.black54,
                      ),
                      hintText: 'Type "True" or "False"',
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white38 : Colors.black38,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFFFFD700).withOpacity(0.3)
                              : const Color(0xFF1565C0).withOpacity(0.3),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: isDark
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1565C0),
                          width: 2,
                        ),
                      ),
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF2A2A2A).withOpacity(0.5)
                          : Colors.white,
                    ),
                  ),
                ],
                const SizedBox(height: 32),
                // Submit button - disabled until answer is provided
                ElevatedButton(
                  onPressed: _canProceed() ? _submitAnswer : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: _canProceed()
                        ? (isDark
                            ? const Color(0xFFFFD700)
                            : const Color(0xFF1565C0))
                        : (isDark
                            ? Colors.grey.shade800
                            : Colors.grey.shade300),
                    foregroundColor: _canProceed()
                        ? (isDark
                            ? Colors.black
                            : Colors.white)
                        : (isDark
                            ? Colors.grey.shade600
                            : Colors.grey.shade600),
                    elevation: _canProceed() ? 4 : 0,
                    disabledBackgroundColor: isDark
                        ? Colors.grey.shade800
                        : Colors.grey.shade300,
                  ),
                  child: Text(
                    _isLastQuestionOverall()
                        ? 'Submit'
                        : 'Next Question',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: _canProceed()
                          ? (isDark ? Colors.black : Colors.white)
                          : (isDark
                              ? Colors.grey.shade600
                              : Colors.grey.shade600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTableQuestion(Map<String, dynamic> question, bool isDark) {
    final tableData = question['tableData'] as Map<String, dynamic>?;
    if (tableData == null) {
      return const Text('Invalid table data');
    }

    final columnHeaders = (tableData['columnHeaders'] as List<dynamic>?) ?? [];
    final rows = (tableData['rows'] as List<dynamic>?) ?? [];
    final answers = question['answers'] as Map<String, dynamic>? ?? {};
    final withOptions = question['withOptions'] as bool? ?? false;
    final options = _tableOptions[_currentGlobalIndex] ?? [];
    final selectedCell = _selectedTableCell[_currentGlobalIndex];
    final userAnswers = _tableUserAnswers[_currentGlobalIndex] ?? {};

    return Column(
      children: [
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2A2A2A).withOpacity(0.7)
                : Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFFFFD700).withOpacity(0.3)
                  : const Color(0xFF1565C0).withOpacity(0.3),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: isDark
                      ? const Color(0xFFFFD700)
                      : const Color(0xFF1565C0),
                  width: 2,
                ),
              ),
              child: IntrinsicHeight(
                child: Table(
                  border: TableBorder.all(
                    color: Colors.grey.withOpacity(0.5),
                    width: 1,
                  ),
                  columnWidths: {
                    for (int i = 0; i <= columnHeaders.length; i++)
                      i: const FixedColumnWidth(150),
                  },
                children: [
                  // Header row
                  TableRow(
                    children: [
                      // First cell (empty for row headers column)
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: const Text(''),
                        ),
                      ),
                      // Column headers
                      ...columnHeaders.map((header) {
                        return TableCell(
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              header.toString(),
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                // Data rows
                ...rows.asMap().entries.map((rowEntry) {
                  final rowIndex = rowEntry.key;
                  final row = rowEntry.value as Map<String, dynamic>;
                  final rowHeader = row['rowHeader']?.toString() ?? '';
                  final cells = (row['cells'] as List<dynamic>?) ?? [];

                  return TableRow(
                    children: [
                      // Row header
                      TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          child: Text(
                            rowHeader,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                            softWrap: true,
                            maxLines: null,
                            overflow: TextOverflow.visible,
                          ),
                        ),
                      ),
                      // Data cells
                      ...cells.asMap().entries.map((cellEntry) {
                        final colIndex = cellEntry.key;
                        final cell = cellEntry.value as Map<String, dynamic>;
                        final cellType = cell['type']?.toString() ?? '';
                        final cellKey = '${rowIndex}_${colIndex}';
                        final userAnswer = userAnswers[cellKey] ?? '';
                        final isSelected = selectedCell == cellKey;

                        // All cells should be blanks for user to fill (data type cells contain answers but are displayed as blanks)
                        final controller = _tableCellControllers[cellKey];
                        // Check if this cell has an answer (is in the answers map)
                        final hasAnswer = answers.containsKey(cellKey);
                        return TableCell(
                          child: InkWell(
                            onTap: withOptions && hasAnswer ? () {
                              setState(() {
                                _selectedTableCell[_currentGlobalIndex] = cellKey;
                              });
                            } : null,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              constraints: const BoxConstraints(
                                minHeight: 60,
                              ),
                              child: withOptions
                                  ? Container(
                                      width: double.infinity,
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isSelected
                                              ? (isDark
                                                  ? const Color(0xFFFFD700)
                                                  : const Color(0xFF1565C0))
                                              : Colors.grey.withOpacity(0.3),
                                          width: isSelected ? 3 : 1,
                                        ),
                                        color: isDark
                                            ? const Color(0xFF1A1A1A)
                                            : Colors.white.withOpacity(0.05),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Center(
                                          child: Text(
                                            userAnswer.isEmpty ? '' : userAnswer,
                                            style: TextStyle(
                                              fontSize: 14,
                                              color: isDark ? Colors.white : Colors.black87,
                                            ),
                                            textAlign: TextAlign.center,
                                            softWrap: true,
                                            maxLines: null,
                                            overflow: TextOverflow.visible,
                                          ),
                                        ),
                                      ),
                                    )
                                    : Container(
                                        width: double.infinity,
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.withOpacity(0.3),
                                            width: 1,
                                          ),
                                          color: isDark
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.white.withOpacity(0.05),
                                        ),
                                        child: TextField(
                                          controller: controller,
                                          decoration: InputDecoration(
                                            hintText: '',
                                            border: InputBorder.none,
                                            contentPadding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 8,
                                            ),
                                          ),
                                          style: TextStyle(
                                            color: isDark ? Colors.white : Colors.black87,
                                            fontSize: 14,
                                          ),
                                          textAlign: TextAlign.center,
                                          maxLines: null,
                                          textInputAction: TextInputAction.newline,
                                          onChanged: (value) {
                                            setState(() {
                                              if (_tableUserAnswers[_currentGlobalIndex] == null) {
                                                _tableUserAnswers[_currentGlobalIndex] = {};
                                              }
                                              _tableUserAnswers[_currentGlobalIndex]![cellKey] = value;
                                            });
                                          },
                                        ),
                                      ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  );
                }).toList(),
              ],
                ),
              ),
            ),
          ),
        ),
        // Options for "with options" mode
        if (withOptions && options.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Select an option to fill the selected cell:',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: options.map((option) {
              // Check if this option has been used (is in any user answer)
              final isUsed = userAnswers.values.any((answer) => 
                answer.toString().trim().toLowerCase() == option.trim().toLowerCase()
              );
              
              return InkWell(
                onTap: selectedCell != null ? () {
                  setState(() {
                    if (_tableUserAnswers[_currentGlobalIndex] == null) {
                      _tableUserAnswers[_currentGlobalIndex] = {};
                    }
                    // Store the answer
                    _tableUserAnswers[_currentGlobalIndex]![selectedCell!] = option;
                    _selectedTableCell[_currentGlobalIndex] = null;
                  });
                } : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isUsed
                        ? (isDark
                            ? const Color(0xFFFFD700).withOpacity(0.3)
                            : const Color(0xFF1565C0).withOpacity(0.3))
                        : (isDark
                            ? const Color(0xFF2A2A2A).withOpacity(0.5)
                            : Colors.white.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isUsed
                          ? (isDark
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1565C0))
                          : (isDark
                              ? const Color(0xFFFFD700).withOpacity(0.3)
                              : const Color(0xFF1565C0).withOpacity(0.3)),
                      width: isUsed ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildTableReview(Map<String, dynamic> question, int index, bool isDark) {
    final tableData = question['tableData'] as Map<String, dynamic>?;
    if (tableData == null) {
      return const Text('Invalid table data');
    }

    final columnHeaders = (tableData['columnHeaders'] as List<dynamic>?) ?? [];
    final rows = (tableData['rows'] as List<dynamic>?) ?? [];
    final answers = question['answers'] as Map<String, dynamic>? ?? {};
    final userAnswers = _tableUserAnswers[index] ?? {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // User Answer Table
        Text(
          'Your Answer:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        _buildReviewTable(columnHeaders, rows, userAnswers, isDark, false),
        const SizedBox(height: 24),
        // Correct Answer Table
        Text(
          'Correct Answer:',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 8),
        _buildReviewTable(columnHeaders, rows, answers, isDark, true),
      ],
    );
  }

  Widget _buildReviewTable(
    List<dynamic> columnHeaders,
    List<dynamic> rows,
    Map<String, dynamic> cellValues,
    bool isDark,
    bool isCorrect,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2A2A2A).withOpacity(0.7)
            : Colors.white.withOpacity(0.9),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFFFFD700).withOpacity(0.3)
              : const Color(0xFF1565C0).withOpacity(0.3),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isDark
                  ? const Color(0xFFFFD700)
                  : const Color(0xFF1565C0),
              width: 2,
            ),
          ),
          child: IntrinsicHeight(
            child: Table(
              border: TableBorder.all(
                color: Colors.grey.withOpacity(0.5),
                width: 1,
              ),
              columnWidths: {
                for (int i = 0; i <= columnHeaders.length; i++)
                  i: const FixedColumnWidth(150),
              },
            children: [
              // Header row
              TableRow(
                children: [
                  TableCell(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      child: const Text(''),
                    ),
                  ),
                  ...columnHeaders.map((header) {
                    return TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          header.toString(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          textAlign: TextAlign.center,
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
              // Data rows
              ...rows.asMap().entries.map((rowEntry) {
                final rowIndex = rowEntry.key;
                final row = rowEntry.value as Map<String, dynamic>;
                final rowHeader = row['rowHeader']?.toString() ?? '';
                final cells = (row['cells'] as List<dynamic>?) ?? [];

                return TableRow(
                  children: [
                    // Row header
                    TableCell(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        child: Text(
                          rowHeader,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          softWrap: true,
                          maxLines: null,
                          overflow: TextOverflow.visible,
                        ),
                      ),
                    ),
                    // Data cells
                    ...cells.asMap().entries.map((cellEntry) {
                      final colIndex = cellEntry.key;
                      final cellKey = '${rowIndex}_${colIndex}';
                      final cellValue = cellValues[cellKey]?.toString() ?? '';

                      return TableCell(
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          width: double.infinity,
                          constraints: const BoxConstraints(
                            minHeight: 60,
                          ),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                              width: 1,
                            ),
                            color: isDark
                                ? const Color(0xFF1A1A1A)
                                : Colors.white.withOpacity(0.05),
                          ),
                          child: Center(
                            child: Text(
                              cellValue,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              textAlign: TextAlign.center,
                              softWrap: true,
                              maxLines: null,
                              overflow: TextOverflow.visible,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                );
              }).toList(),
            ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailedResultScreen(bool isDark) {
    final score = _isCorrect.values.where((correct) => correct).length;
    final total = widget.questions.length;
    final percentage = total > 0 ? (score / total * 100).round() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Quiz Results'),
        backgroundColor: isDark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFE3F2FD),
        foregroundColor: isDark
            ? const Color(0xFFFFD700)
            : const Color(0xFF1565C0),
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    Colors.black,
                    const Color(0xFF1A1A1A),
                  ]
                : [
                    Colors.white,
                    const Color(0xFFE3F2FD),
                  ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Score display
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF2A2A2A).withOpacity(0.7)
                        : Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFFFFD700).withOpacity(0.3)
                          : const Color(0xFF1565C0).withOpacity(0.3),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '$score / $total',
                        style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFFFFD700)
                              : const Color(0xFF1565C0),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '$percentage%',
                        style: TextStyle(
                          fontSize: 24,
                          color: isDark
                              ? Colors.white70
                              : Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Questions list
                Text(
                  'Question Review',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                  ),
                ),
                const SizedBox(height: 16),
                ...widget.questions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final question = entry.value;
                  final userAnswer = _userAnswers[index] ?? 'No answer';
                  final correctAnswer = _correctAnswers[index] ?? '';
                  final isCorrect = _isCorrect[index] ?? false;
                  final questionText = question['question']?.toString() ?? '';
                  final quizType = question['quizType'] as String?;
                  final isTrueOrFalse = quizType == 'trueOrFalse';
                  
                  // Get displayed answer for true/false questions
                  final displayedAnswer = isTrueOrFalse 
                      ? (_trueFalseDisplayedAnswers[index] ?? '')
                      : '';
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF2A2A2A).withOpacity(0.7)
                          : Colors.white.withOpacity(0.9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isCorrect
                            ? Colors.green.withOpacity(0.5)
                            : Colors.red.withOpacity(0.5),
                        width: 2,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              isCorrect ? Icons.check_circle : Icons.cancel,
                              color: isCorrect ? Colors.green : Colors.red,
                              size: 24,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Question ${index + 1}',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          quizType == 'fillInTheBlankTable' ? 'Fill in the Table' : questionText,
                          style: TextStyle(
                            fontSize: 16,
                            color: isDark ? Colors.white70 : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 12),
                        // Show tables for table questions, otherwise show text answers
                        if (quizType == 'fillInTheBlankTable') ...[
                          _buildTableReview(question, index, isDark),
                        ] else ...[
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.3)
                                : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                                // Show "Answer being defined" for true/false questions
                                if (isTrueOrFalse && displayedAnswer.isNotEmpty) ...[
                                  Text(
                                    'Answer being defined: $displayedAnswer',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: isDark ? Colors.white70 : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                ],
                              Text(
                                'Your Answer: $userAnswer',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: isDark ? Colors.white70 : Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Correct Answer: $correctAnswer',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ),
                        ],
                      ],
                    ),
                  );
                }),
                const SizedBox(height: 32),
                // Back to home button
                ElevatedButton(
                  onPressed: _finishQuiz,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFFFFD700)
                        : const Color(0xFF1565C0),
                    foregroundColor: isDark
                        ? Colors.black
                        : Colors.white,
                    elevation: 4,
                  ),
                  child: const Text(
                    'Back to Home',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
