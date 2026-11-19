import 'package:flutter/material.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';
import 'package:touchin_flutter/dev_preview/preview_workspace.dart';
import 'package:touchin_flutter/main.dart';
import 'package:touchin_flutter/dev_preview/preview_theme.dart';

/// No real app, session storage or authenticated bootstrap is constructed until
/// the developer explicitly chooses the normal application.
class PreviewLauncher extends StatefulWidget {
  const PreviewLauncher({super.key});

  @override
  State<PreviewLauncher> createState() => _PreviewLauncherState();
}

class _PreviewLauncherState extends State<PreviewLauncher> {
  bool? _preview;

  @override
  Widget build(BuildContext context) {
    if (!developerPreviewAvailable || _preview == false) return const MyApp();
    if (_preview == true) {
      return PreviewWorkspace(onExit: () => setState(() => _preview = null));
    }
    return MaterialApp(
      title: 'TouchIn — desenvolvimento',
      debugShowCheckedModeBanner: false,
      theme: previewTheme(Brightness.dark),
      // A protected deep link still stops here before any stored session read.
      onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (context) => Scaffold(
                body: SafeArea(
                    child: Center(
                        child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 460),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Icon(Icons.science_outlined, size: 48),
                        const SizedBox(height: 20),
                        Text('TouchIn • Desenvolvimento',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.headlineSmall),
                        const SizedBox(height: 16),
                        const Text(
                            'Explore a interface com dados inteiramente fictícios, sem conta, servidor ou configuração.',
                            textAlign: TextAlign.center),
                        const SizedBox(height: 24),
                        FilledButton(
                            onPressed: () {
                              requireDeveloperPreview();
                              setState(() => _preview = true);
                            },
                            child: const Text(
                                'Entrar na prévia de desenvolvimento')),
                        const SizedBox(height: 12),
                        OutlinedButton(
                            onPressed: () => setState(() => _preview = false),
                            child: const Text('Abrir login normal')),
                      ],
                    ),
                  ),
                ))),
              )),
    );
  }
}
