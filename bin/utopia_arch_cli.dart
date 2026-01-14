#!/usr/bin/env dart

import 'dart:io';
import 'package:args/args.dart';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as path;

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'name',
      abbr: 'n',
      mandatory: true,
      help: 'Project name (must not contain \'-\' character)',
    )
    ..addOption(
      'org',
      abbr: 'o',
      mandatory: true,
      help: 'Organization name (e.g., "io.utopiasoft")',
    )
    ..addOption(
      'platforms',
      abbr: 'p',
      defaultsTo: 'android,ios',
      help: 'Platforms to support (e.g., "android,ios")',
    )
    ..addOption(
      'output',
      abbr: 'd',
      defaultsTo: '.',
      help: 'Output directory (default: current directory)',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show this help message',
    );

  try {
    final results = parser.parse(arguments);

    if (results['help'] == true) {
      _printUsage(parser);
      exit(0);
    }

    final projectName = results['name'] as String;
    final orgName = results['org'] as String;
    final platforms = results['platforms'] as String;
    final outputDir = results['output'] as String;

    // Validate project name
    if (!_isValidProjectName(projectName)) {
      print('❌ Error: Project name must not contain \'-\' character');
      print(
          '   Use underscores or camelCase instead (e.g., "my_app" or "myApp")');
      exit(1);
    }

    // Validate org name
    if (!_isValidOrgName(orgName)) {
      print('❌ Error: Invalid organization name format');
      print('   Use reverse domain notation (e.g., "io.utopiasoft")');
      exit(1);
    }

    // Package name comes directly from project name (not org.project)
    final packageName = projectName;

    // Check if output directory exists and is writable
    final outputPath = path.isAbsolute(outputDir)
        ? Directory(outputDir)
        : Directory(path.join(Directory.current.path, outputDir));

    final projectPath = path.join(outputPath.path, projectName);

    if (Directory(projectPath).existsSync()) {
      print('❌ Error: Directory "$projectPath" already exists');
      exit(1);
    }

    print('🚀 Creating Utopia Flutter project...');
    print('   Project name: $projectName');
    print('   Organization: $orgName');
    print('   Package name: $packageName');
    print('   Platforms: $platforms');
    print('   Output: $projectPath\n');

    // Step 1: Create empty directory
    print('📁 Creating project directory...');
    await Directory(projectPath).create(recursive: true);

    // Step 2: Initialize git repository
    print('📦 Initializing git repository...');
    await _initGitRepository(projectPath);

    // Step 3: Create full Flutter project structure first
    // This creates android/, ios/, web/, etc. and basic Flutter structure
    // Must be done in empty directory
    print('🔧 Creating Flutter project structure...');
    await _createFlutterProject(
      projectPath: projectPath,
      projectName: projectName,
      orgName: orgName,
      platforms: platforms,
    );

    // Step 4: Apply Utopia template on top
    // This will override/merge with Flutter's default files
    print('🎨 Applying Utopia template...');
    await _generateProject(
      projectName: projectName,
      orgName: orgName,
      packageName: packageName,
      platforms: platforms,
      outputPath: projectPath,
    );

    // Step 4: Setup FVM if .fvmrc exists in template
    print('📋 Setting up FVM...');
    await _setupFVM(projectPath);

    // Step 5: Ensure .gitignore has required entries for generated files
    print('📝 Ensuring .gitignore is configured...');
    await _ensureGitignore(projectPath);

    // Step 6: Install dependencies
    print('📥 Installing dependencies...');
    await _installDependencies(projectPath);

    // Step 7: Stage all files with git add
    print('📦 Staging files with git add...');
    await _gitAddAll(projectPath);

    print('\n✅ Project created successfully!');
    print('\n📋 Next steps:');
    print('   1. cd $projectName');
    print('   2. Update app_localizations.dart with doc id and sheet id');
    
    // Check if FVM should be used
    final fvmrcPath = path.join(projectPath, '.fvmrc');
    final useFVM = File(fvmrcPath).existsSync();
    final fvmPrefix = useFVM ? 'fvm ' : '';
    
    print('   3. Run code generation: ${fvmPrefix}dart run build_runner build');
  } on FormatException catch (e) {
    print('❌ Error: ${e.message}');
    _printUsage(parser);
    exit(1);
  } catch (e) {
    print('❌ Error: $e');
    exit(1);
  }
}

void _printUsage(ArgParser parser) {
  print('Utopia Arch CLI - Create Flutter projects based on utopia_arch\n');
  print('Usage: utopia_arch_cli [options]\n');
  print('Options:');
  print(parser.usage);
  print('\nExample:');
  print('  utopia_arch_cli --name my_app --org io.utopiasoft');
  print('  utopia_arch_cli -n my_app -o io.utopiasoft -p android,ios');
}

bool _isValidProjectName(String name) {
  return name.isNotEmpty && !name.contains('-');
}

bool _isValidOrgName(String org) {
  // Basic validation: should be reverse domain notation
  return org.isNotEmpty &&
      org.contains('.') &&
      !org.startsWith('.') &&
      !org.endsWith('.');
}

Future<void> _generateProject({
  required String projectName,
  required String orgName,
  required String packageName,
  required String platforms,
  required String outputPath,
}) async {
  try {
    // Get the path to the brick
    // When installed globally, we need to find the package in pub cache
    final scriptPath = Platform.script.toFilePath();
    String brickPath;

    // Try multiple strategies to find the brick
    final possiblePaths = <String>[];

    // Strategy 1: If script is in pub cache (global installation)
    if (scriptPath.contains('.pub-cache')) {
      // For global packages, the structure is:
      // .pub-cache/global_packages/utopia_arch_cli/bin/utopia_arch_cli.dart
      // But the actual package is in:
      // .pub-cache/hosted/pub.dev/utopia_arch_cli-VERSION/
      
      // Try to find package in hosted cache
      final pubCacheDir = scriptPath.split('.pub-cache')[0] + '.pub-cache';
      final hostedDir = path.join(pubCacheDir, 'hosted', 'pub.dev');
      
      if (Directory(hostedDir).existsSync()) {
        // Look for utopia_arch_cli packages
        final hostedDirList = Directory(hostedDir).listSync();
        for (final entry in hostedDirList) {
          if (entry is Directory && entry.path.contains('utopia_arch_cli-')) {
            final packageBrickPath = path.join(entry.path, 'bricks', 'utopia_template');
            if (Directory(packageBrickPath).existsSync()) {
              possiblePaths.add(packageBrickPath);
            }
          }
        }
      }
      
      // Also try the global_packages location
      final globalPackagesDir = path.join(pubCacheDir, 'global_packages', 'utopia_arch_cli');
      if (Directory(globalPackagesDir).existsSync()) {
        final globalBrickPath = path.join(globalPackagesDir, 'bricks', 'utopia_template');
        possiblePaths.add(globalBrickPath);
      }
    }

    // Strategy 2: Relative to script (local development or global)
    final scriptDir = path.dirname(scriptPath);
    final scriptBrickPath = path.join(path.dirname(scriptDir), 'bricks', 'utopia_template');
    possiblePaths.add(scriptBrickPath);

    // Strategy 3: Relative to current directory (for development)
    final currentDirBrick = path.join(Directory.current.path, 'bricks', 'utopia_template');
    possiblePaths.add(currentDirBrick);

    // Find the first existing brick path
    brickPath = possiblePaths.firstWhere(
      (p) => Directory(p).existsSync(),
      orElse: () => '',
    );

    if (brickPath.isEmpty) {
      throw Exception(
        'Brick not found. Tried:\n'
        '${possiblePaths.map((p) => '  - $p').join('\n')}\n'
        'Make sure the utopia_template brick is properly configured. '
        'If you installed from pub.dev, this might be a packaging issue.',
      );
    }

    // Create Mason generator from brick
    final generator = await MasonGenerator.fromBrick(
      Brick.path(brickPath),
    );

    // Create target directory
    final target = DirectoryGeneratorTarget(Directory(outputPath));

    // Generate project with variables
    await generator.generate(
      target,
      vars: {
        'project_name': projectName,
        'org_name': orgName,
        'package_name': packageName,
        'platforms': platforms,
        'dart_package_name':
            packageName, // For backward compatibility with template
      },
    );
  } catch (e) {
    throw Exception('Failed to generate project: $e');
  }
}

Future<void> _initGitRepository(String projectPath) async {
  try {
    final result = await Process.run(
      'git',
      ['init'],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      print(
          '⚠️  Warning: Failed to initialize git repository: ${result.stderr}');
      print('   You can run "git init" manually later.');
    }
  } catch (e) {
    // Git might not be installed, that's okay
    print('⚠️  Warning: Could not initialize git repository: $e');
    print('   You can run "git init" manually later.');
  }
}

Future<void> _createFlutterProject({
  required String projectPath,
  required String projectName,
  required String orgName,
  required String platforms,
}) async {
  // Try to find Flutter command (fvm flutter or flutter)
  bool useFVM = false;

  // Check if FVM is available (prefer FVM if available)
  try {
    final fvmCheck = await Process.run('fvm', ['--version']);
    if (fvmCheck.exitCode == 0) {
      useFVM = true;
    }
  } catch (e) {
    // FVM not available, will use regular flutter
  }

  // Check if flutter is available
  try {
    final flutterCheck = await Process.run(
      useFVM ? 'fvm' : 'flutter',
      useFVM ? ['flutter', '--version'] : ['--version'],
    );
    if (flutterCheck.exitCode != 0) {
      throw Exception('Flutter command not available');
    }
  } catch (e) {
    throw Exception(
      'Flutter SDK not found. '
      'Please install Flutter or FVM and make sure it\'s in your PATH.',
    );
  }

  // Build flutter create command
  final args = useFVM
      ? [
          'flutter',
          'create',
          '--project-name=$projectName',
          '--org=$orgName',
          '--platforms=$platforms',
          '.',
        ]
      : [
          'create',
          '--project-name=$projectName',
          '--org=$orgName',
          '--platforms=$platforms',
          '.',
        ];

  print('   Running: ${useFVM ? 'fvm' : ''} flutter create ${args.join(' ')}');

  final result = await Process.run(
    useFVM ? 'fvm' : 'flutter',
    args,
    workingDirectory: projectPath,
  );

  if (result.exitCode != 0) {
    throw Exception(
      'Failed to create Flutter project: ${result.stderr}\n${result.stdout}',
    );
  }

  print('   ✅ Flutter project structure created');

  // Remove test folder (not needed in template)
  final testDir = Directory(path.join(projectPath, 'test'));
  if (testDir.existsSync()) {
    try {
      await testDir.delete(recursive: true);
      print('   🗑️  Removed test folder');
    } catch (e) {
      print('   ⚠️  Warning: Could not remove test folder: $e');
    }
  }
}

Future<void> _setupFVM(String projectPath) async {
  final fvmrcPath = path.join(projectPath, '.fvmrc');
  if (!File(fvmrcPath).existsSync()) {
    print('   ℹ️  No .fvmrc file found, skipping FVM setup');
    return;
  }

  try {
    // Check if fvm command exists
    final fvmCheck = await Process.run('fvm', ['--version']);
    if (fvmCheck.exitCode != 0) {
      print('   ⚠️  FVM not found, but .fvmrc exists');
      print('   Install FVM: https://fvm.app/documentation/getting-started');
      return;
    }

    print('   Running: fvm use');
    final result = await Process.run(
      'fvm',
      ['use'],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      print('   ⚠️  Warning: FVM setup failed: ${result.stderr}');
      print('   You can run "fvm use" manually later.');
    } else {
      print('   ✅ FVM configured');
    }
  } catch (e) {
    print('   ⚠️  Warning: Could not setup FVM: $e');
    print('   You can run "fvm use" manually later.');
  }
}

Future<void> _ensureGitignore(String projectPath) async {
  final gitignorePath = path.join(projectPath, '.gitignore');
  final gitignoreFile = File(gitignorePath);

  // Required entries for generated files
  final requiredEntries = [
    '**/*.g.dart',
    '**/*.freezed.dart',
  ];

  if (!gitignoreFile.existsSync()) {
    // If .gitignore doesn't exist, create it with required entries
    // (This shouldn't happen as flutter create creates one, but just in case)
    await gitignoreFile.writeAsString(
      '# Generated files\n'
      '**/*.g.dart\n'
      '**/*.freezed.dart\n',
    );
    print('   ✅ Created .gitignore with required entries');
    return;
  }

  // Read existing .gitignore
  final content = await gitignoreFile.readAsString();
  final lines = content.split('\n');

  // Check if required entries exist
  bool needsUpdate = false;
  final existingEntries = lines.map((line) => line.trim()).toSet();

  for (final entry in requiredEntries) {
    if (!existingEntries.contains(entry)) {
      needsUpdate = true;
      break;
    }
  }

  if (needsUpdate) {
    // Append required entries if they don't exist
    final updatedContent = StringBuffer(content);
    if (!content.endsWith('\n')) {
      updatedContent.write('\n');
    }
    updatedContent.write('\n# Generated files (added by utopia_arch_cli)\n');
    for (final entry in requiredEntries) {
      if (!existingEntries.contains(entry)) {
        updatedContent.writeln(entry);
      }
    }

    await gitignoreFile.writeAsString(updatedContent.toString());
    print('   ✅ Updated .gitignore with required entries');
  } else {
    print('   ✅ .gitignore already configured');
  }
}

Future<void> _gitAddAll(String projectPath) async {
  try {
    // Check if git is initialized
    final gitDir = Directory(path.join(projectPath, '.git'));
    if (!gitDir.existsSync()) {
      print('   ⚠️  Warning: Git repository not initialized, skipping git add');
      return;
    }

    final result = await Process.run(
      'git',
      ['add', '*'],
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      print('   ⚠️  Warning: Failed to stage files: ${result.stderr}');
      print('   You can run "git add *" manually later.');
    } else {
      print('   ✅ Files staged with git add');
    }
  } catch (e) {
    print('   ⚠️  Warning: Could not stage files: $e');
    print('   You can run "git add *" manually later.');
  }
}

Future<void> _installDependencies(String projectPath) async {
  bool useFVM = false;

  // Check if FVM is available
  try {
    final fvmCheck = await Process.run('fvm', ['--version']);
    if (fvmCheck.exitCode == 0) {
      // Check if .fvmrc exists
      final fvmrcPath = path.join(projectPath, '.fvmrc');
      if (File(fvmrcPath).existsSync()) {
        useFVM = true;
      }
    }
  } catch (e) {
    // FVM not available, use regular dart
  }

  try {
    final command = useFVM ? 'fvm' : 'dart';
    final args = useFVM ? ['dart', 'pub', 'get'] : ['pub', 'get'];

    print('   Running: $command ${args.join(' ')}');
    final result = await Process.run(
      command,
      args,
      workingDirectory: projectPath,
    );

    if (result.exitCode != 0) {
      print('   ⚠️  Warning: Failed to install dependencies: ${result.stderr}');
      print(
          '   You can run "${useFVM ? 'fvm ' : ''}dart pub get" manually later.');
    } else {
      print('   ✅ Dependencies installed');
    }
  } catch (e) {
    print('   ⚠️  Warning: Could not install dependencies: $e');
    print(
        '   You can run "${useFVM ? 'fvm ' : ''}dart pub get" manually later.');
  }
}
