import "dart:io";
import "package:args/command_runner.dart";
import "package:console/console.dart";
import 'package:random_string/random_string.dart' as rs;
import 'package:path/path.dart' as p;
import 'key.dart';
import 'rename.dart';

class InitCommand extends Command {
  final KeyCommand _key = new KeyCommand();
  final TextPen _pen = new TextPen();

  @override
  String get name => "init";

  @override
  String get description =>
      "Initializes a new Angel project in the current directory.";

  InitCommand() {}

  @override
  run() async {
    Directory projectDir = new Directory(
        argResults.arguments.isEmpty ? "." : argResults.arguments[0]);
    print("Creating new Angel project in ${projectDir.absolute.path}...");
    await _cloneRepo(projectDir);
    // await preBuild(projectDir);
    var secret = rs.randomAlphaNumeric(32);
    print('Generated new development JWT secret: $secret');
    await _key.changeSecret(
        new File.fromUri(projectDir.uri.resolve('config/default.yaml')),
        secret);

    secret = rs.randomAlphaNumeric(32);
    print('Generated new production JWT secret: $secret');
    await _key.changeSecret(
        new File.fromUri(projectDir.uri.resolve('config/production.yaml')),
        secret);

    var name = p.basenameWithoutExtension(projectDir.path);
    print('Renaming project from "angel" to "$name"...');
    await renamePubspec(projectDir, 'angel', name);
    await renameDartFiles(projectDir, 'angel', name);
    _pen.green();
    _pen(
        "${Icon.CHECKMARK} Successfully initialized Angel project. Now running pub get...");
    _pen();
    await _pubGet(projectDir);
  }

  _cloneRepo(Directory projectDir) async {
    try {
      if (await projectDir.exists()) {
        var chooser = new Chooser(["Yes", "No"],
            message:
                "Directory '${projectDir.absolute.path}' exists. Overwrite it? (Yes/No)");

        if (await chooser.choose() != "Yes")
          throw new Exception("Chose not to overwrite existing directory.");
        await projectDir.delete(recursive: true);
      }

      var git = await Process.start("git", [
        "clone",
        "--depth",
        "1",
        "https://github.com/angel-dart/angel",
        projectDir.absolute.path
      ]);

      stdout.addStream(git.stdout);
      stderr.addStream(git.stderr);

      if (await git.exitCode != 0) {
        throw new Exception("Could not clone repo.");
      }

      var gitDir = new Directory.fromUri(projectDir.uri.resolve(".git"));

      if (await gitDir.exists()) await gitDir.delete(recursive: true);
    } catch (e) {
      print(e);
      _pen.red();
      _pen("${Icon.BALLOT_X} Could not initialize Angel project.");
      _pen();
      rethrow;
    }
  }

  _pubGet(Directory projectDir) async {
    var pub = await Process.start("pub", ["get"],
        workingDirectory: projectDir.absolute.path);
    stdout.addStream(pub.stdout);
    stderr.addStream(pub.stderr);
    var code = await pub.exitCode;
    print("Pub process exited with code $code");
  }
}

preBuild(Directory projectDir) async {
  // Run build
  print('Pre-building resources...');

  var build = await Process.start(Platform.executable, ['tool/build.dart'],
      workingDirectory: projectDir.absolute.path);

  stdout.addStream(build.stdout);
  stderr.addStream(build.stderr);

  var buildCode = await build.exitCode;

  if (buildCode != 0) throw new Exception('Failed to pre-build resources.');
}
