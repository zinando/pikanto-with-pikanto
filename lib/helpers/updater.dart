import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:version/version.dart';
import 'package:path_provider/path_provider.dart';
import 'package:archive/archive_io.dart';
import 'package:process_run/shell.dart';
import 'package:pikanto/resources/settings.dart';

class AppUpdater {
  final String updateFileUrl;
  final String currentVersion;
  final String fileName = 'Release.zip';
  final String appFolderName = 'pikanto';
  final String appExecutableName = 'pikanto.exe';

  const AppUpdater({
    required this.updateFileUrl,
    required this.currentVersion,
  });

  // method to check for update
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      final response = await http.get(Uri.parse(updateFileUrl));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = Version.parse(data['latest_version']);
        final downloadUrl = data['download_url'];
        // print('Latest version: ${latestVersion.toString()}');
        // print('Download URL: $downloadUrl');
        // print('Current version: $currentVersion');

        if (Version.parse(currentVersion) < latestVersion) {
          // Ask user for confirmation
          bool userConfirmed =
              await _showUpdateDialog(context, latestVersion.toString());
          if (userConfirmed) {
            await downloadAndInstallUpdate(context, downloadUrl);
          }
        } else {
          throw Exception('No updates available.');
        }
      } else {
        throw Exception('Failed to check for updates.');
      }
    } catch (e) {
      print('$e');
    }

    return;
  }

  // method to show confirmation dialogue
  Future<bool> _showUpdateDialog(
      BuildContext context, String latestVersion) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black.withOpacity(0.9),
          barrierDismissible: false,
          barrierLabel: 'Update to latest version',
          builder: (BuildContext context) {
            return AlertDialog(
              //add icon
              icon: const Icon(Icons.update),
              iconColor: Theme.of(context).colorScheme.tertiary,
              backgroundColor: Colors.white,
              elevation: 2.0,
              shadowColor: Colors.grey[200],
              surfaceTintColor: Colors.grey[200],
              semanticLabel: 'Update to latest version',
              title: const Text("Update Available"),
              titleTextStyle: const TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                  fontSize: 18),
              content: Text(
                  "A new version ($latestVersion) is available. Would you like to update now?"),
              contentTextStyle:
                  TextStyle(color: Colors.grey[800], fontSize: 16),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    foregroundColor: Theme.of(context).colorScheme.tertiary,
                  ),
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text("No"),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.tertiary,
                    foregroundColor: Colors.white,
                    elevation: 2.0,
                  ),
                  child: const Text("Yes, update now"),
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  // method to download
  Future<void> downloadAndInstallUpdate(
      BuildContext context, String downloadUrl) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final zipFilePath = "${tempDir.path}/Release.zip";
      final extractedPath = "${tempDir.path}/Release";

      final request = http.Request('GET', Uri.parse(downloadUrl));
      final streamedResponse = await request.send();
      final contentLength = streamedResponse.contentLength ?? 0;

      if (streamedResponse.statusCode == 200) {
        final file = File(zipFilePath);
        final sink = file.openWrite();
        int downloadedBytes = 0;

        // Show download progress
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) {
            return StatefulBuilder(
              builder: (context, setState) {
                return AlertDialog(
                  title: const Text("Downloading Update"),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text("Downloading update... Please wait."),
                      const SizedBox(height: 10),
                      LinearProgressIndicator(
                          value: downloadedBytes / contentLength),
                    ],
                  ),
                );
              },
            );
          },
        );

        await for (var chunk in streamedResponse.stream) {
          downloadedBytes += chunk.length;
          sink.add(chunk);
        }

        await sink.close();
        Navigator.pop(context); // Close progress dialog

        print("Update downloaded successfully.");

        // Extract ZIP
        //await extractZipFile(zipFilePath, extractedPath);

        // Install the update
        //await installUpdate(extractedPath, appFolderName, appExecutableName);
      } else {
        print("Failed to download update.");
      }
    } catch (e) {
      print("Error downloading update: $e");
    }
  }

  // method to extract zip file
  Future<void> extractZipFile(String zipFilePath, String extractedPath) async {
    final inputStream = InputFileStream(zipFilePath);
    final archive = ZipDecoder().decodeBuffer(inputStream);

    for (final file in archive) {
      final filePath = "$extractedPath/${file.name}";
      if (file.isFile) {
        final outputStream = OutputFileStream(filePath);
        file.writeContent(outputStream);
        await outputStream.close();
      } else {
        Directory(filePath).createSync(recursive: true);
      }
    }
    print("Extraction complete.");
  }

  // method to install update
  Future<void> installUpdate(String extractedPath, String appFolderName,
      String appExecutableName) async {
    try {
      final appDir = Directory.current.path;
      final oldAppPath = "$appDir/$appFolderName";
      final newAppPath = "$extractedPath/$appFolderName";

      // Backup old version
      final backupPath = "$oldAppPath.bak";
      if (Directory(oldAppPath).existsSync()) {
        Directory(oldAppPath).renameSync(backupPath);
      }

      // Move new version to app directory
      Directory(newAppPath).renameSync(oldAppPath);

      // update app current version in settings
      settingsData['currentAppVersion'] =
          Version.parse(currentVersion).toString();

      // Restart the app
      await restartApp("$oldAppPath/$appExecutableName");
    } catch (e) {
      print("Error installing update: $e");
    }
  }

  // method to restart app
  Future<void> restartApp(String appExecutablePath) async {
    final shell = Shell();
    await shell.run(appExecutablePath);
    exit(0);
  }
}
