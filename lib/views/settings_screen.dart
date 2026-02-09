import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/localization_service.dart';

class SettingsScreen extends StatelessWidget {
  final TextEditingController tokenController;
  final VoidCallback onLanguageToggle;

  const SettingsScreen({
    super.key,
    required this.tokenController,
    required this.onLanguageToggle,
  });

  Future<void> _launchGitHub() async {
    const url =
        'https://github.com/settings/tokens/new?scopes=repo&description=AmanaSDK';
    if (!await launchUrl(Uri.parse(url))) throw 'Could not launch $url';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(Localization.t('settings')),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(40.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              Localization.t('git_token'),
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: tokenController,
              obscureText: true,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.05),
                border: const OutlineInputBorder(),
                hintText: "ghp_xxxxxxxxxxxx",
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                children: [
                  Text(
                    Localization.t('git_help'),
                    style: const TextStyle(fontSize: 13),
                  ),
                  TextButton(
                    onPressed: _launchGitHub,
                    child: Text(Localization.t('git_link_text')),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  onLanguageToggle();
                  Navigator.pop(context);
                },
                child: Text("Mudar Idioma / Change Language"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
