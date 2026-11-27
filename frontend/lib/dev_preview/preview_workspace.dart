import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:touchin_flutter/dev_preview/preview_api.dart';
import 'package:touchin_flutter/dev_preview/preview_controller.dart';
import 'package:touchin_flutter/dev_preview/preview_fixtures.dart';
import 'package:touchin_flutter/dev_preview/preview_theme.dart';
import 'package:touchin_flutter/main.dart';
import 'package:touchin_flutter/features/time_tracking/application/punch_location_service.dart';
import 'package:touchin_flutter/theme/workspace_menu_style.dart';

class PreviewWorkspace extends StatefulWidget {
  const PreviewWorkspace({super.key, required this.onExit, this.controller});
  final VoidCallback onExit;
  final PreviewController? controller;

  @override
  State<PreviewWorkspace> createState() => _PreviewWorkspaceState();
}

class _PreviewWorkspaceState extends State<PreviewWorkspace>
    with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _controlsNavigatorKey =
      GlobalKey<NavigatorState>();
  late final PreviewController _controller;
  late final PreviewFixtures _fixtures;
  late final PreviewTokenStorage _storage;
  late final PreviewApi _api;
  late String _path;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    requireDeveloperPreview();
    _controller = widget.controller ?? PreviewController();
    _fixtures = PreviewFixtures();
    _storage = PreviewTokenStorage(_controller, _fixtures);
    _api = PreviewApi(_controller, _fixtures, _storage);
    _path = WidgetsBinding.instance.platformDispatcher.defaultRouteName;
    _controller.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  void _onLocationChanged(String path) {
    if (_path == path) return;
    _path = path;
    _controller.cancelRequests();
  }

  Future<bool> _maybePopControlsMenu() async {
    final navigator = _controlsNavigatorKey.currentState;
    if (navigator == null || !navigator.canPop()) return false;
    return navigator.maybePop();
  }

  /// Browser/back on a URL strategy reaches a local Navigator as either a
  /// pop request or a pushed route, depending on which history entry is
  /// active. Dismiss the open dropdown menu in both cases, but return false so
  /// the application router still handles the original navigation.
  @override
  Future<bool> didPopRoute() => _maybePopControlsMenu();

  @override
  Future<bool> didPushRouteInformation(
      RouteInformation routeInformation) async {
    await _maybePopControlsMenu();
    return false;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_refresh);
    if (widget.controller == null) {
      _controller.dispose();
    } else {
      _controller.cancelRequests(includeBoot: true);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    requireDeveloperPreview();
    return MyApp(
      key: ValueKey(_controller.sessionRevision),
      theme: previewTheme(Brightness.light),
      darkTheme: previewTheme(Brightness.dark),
      api: _api, tokenStorage: _storage, initialPath: _path,
      workspaceApi: _api,
      punchLocationService: const _PreviewLocationService(),
      workspaceRevision: _controller.pageRevision,
      onLocationChanged: _onLocationChanged,
      onLogout: widget.onExit,
      // Every possible unauthenticated result stays inside the local preview.
      unauthenticatedBuilder: (_) => Scaffold(
          body: Center(
              child: FilledButton(
                  onPressed: widget.onExit,
                  child: const Text('Sair da prévia')))),
      applicationBuilder: (context, child) => Scaffold(
        endDrawer: Drawer(
          width: math.min(380, MediaQuery.sizeOf(context).width * 0.96),
          // A local Navigator gives the five dropdowns a valid ancestor for
          // their transient menu routes without changing application routing.
          child: HeroControllerScope.none(
            child: Navigator(
              key: _controlsNavigatorKey,
              onGenerateRoute: (_) => MaterialPageRoute<void>(
                builder: (_) => _PreviewControls(
                    controller: _controller,
                    onReset: () {
                      _fixtures.reset();
                      _controller.reset();
                    },
                    onExit: widget.onExit),
              ),
            ),
          ),
        ),
        body: Column(children: [
          Material(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Expanded(
                        child: Text(
                            'PRÉVIA LOCAL · ${_controller.persona.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.labelMedium)),
                    Builder(
                        builder: (context) => TextButton.icon(
                            key: const ValueKey('preview-controls'),
                            onPressed: () =>
                                Scaffold.of(context).openEndDrawer(),
                            icon: const Icon(Icons.science_outlined),
                            label: const Text('Controles'))),
                    IconButton(
                        onPressed: widget.onExit,
                        tooltip: 'Sair da prévia',
                        icon: const Icon(Icons.close)),
                  ]),
                )),
          ),
          Expanded(child: child),
        ]),
      ),
    );
  }
}

class _PreviewLocationService extends PunchLocationService {
  const _PreviewLocationService();
  @override
  Future<PunchLocationResult> requestPermission() async =>
      const PunchLocationResult.unsupported(
          message:
              '[Prévia] GPS não é simulado. Nenhuma localização real é solicitada.');
  @override
  Future<PunchLocationResult> captureForPunch() => requestPermission();
}

class _PreviewControls extends StatelessWidget {
  const _PreviewControls(
      {required this.controller, required this.onReset, required this.onExit});
  final PreviewController controller;
  final VoidCallback onReset;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) => SafeArea(
          child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(children: [
            Expanded(
                child: Text('Controles de desenvolvimento',
                    style: Theme.of(context).textTheme.titleLarge)),
            IconButton(
                tooltip: 'Fechar controles',
                onPressed: () => Scaffold.of(context).closeEndDrawer(),
                icon: const Icon(Icons.close)),
          ]),
          const SizedBox(height: 8),
          const Text(
              'Identidade sintética • dados apenas em memória. Nenhuma chamada à API real.'),
          const SizedBox(height: 20),
          _select(
              context,
              'Perfil fictício',
              controller.persona,
              PreviewPersona.values,
              const ['Administrador', 'Gestor', 'Funcionário'],
              controller.setPersona),
          _select(
              context,
              'Dados da página',
              controller.data,
              PreviewData.values,
              const ['Preenchidos', 'Vazios', 'Erro simulado'],
              (value) => controller.configure(data: value)),
          _select(
              context,
              'Tempo das requisições',
              controller.timing,
              PreviewTiming.values,
              const ['Instantâneo', 'Com atraso', 'Pendente até cancelar'],
              (value) => controller.configure(timing: value)),
          _select(
              context,
              'Atraso',
              controller.delay.inMilliseconds,
              const [250, 1000, 2000, 5000, 8000],
              const [
                '250 ms',
                '1 segundo',
                '2 segundos',
                '5 segundos',
                '8 segundos'
              ],
              (value) =>
                  controller.configure(delay: Duration(milliseconds: value))),
          const Divider(height: 32),
          _select(
              context,
              'Inicialização do servidor',
              controller.server,
              PreviewServer.values,
              const [
                'Pronto',
                'Inicialização com atraso',
                'Indisponível',
                'Falha e sucesso ao tentar novamente'
              ],
              (value) => controller.restartServer(value)),
          OutlinedButton(
              onPressed: () => controller.restartServer(),
              child: const Text('Repetir inicialização')),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: () =>
                  controller.configure(timing: PreviewTiming.instant),
              child: const Text('Cancelar pendências e recarregar')),
          const SizedBox(height: 12),
          FilledButton(
              onPressed: onReset,
              child: const Text('Restaurar dados e cenário')),
          const SizedBox(height: 12),
          OutlinedButton(
              onPressed: onExit, child: const Text('Sair da prévia')),
          const SizedBox(height: 16),
          const Text(
              'As alterações de dados recarregam a página, preservando a navegação. '
              'A inicialização é independente dos atrasos da página. Para recuperar um erro, '
              'selecione “Preenchidos”. Os botões normais de tentar novamente repetem o cenário atual.'),
          const SizedBox(height: 12),
          const Text(
              'Não simulados: cadastro/login reais, senhas, exportação CSV e localização GPS. '
              'Operações sem simulação mostram um erro identificado e permanecem offline. '
              'Configurações visuais podem salvar preferências locais de aparência.'),
        ],
      ));

  Widget _select<T>(BuildContext context, String label, T value,
          List<T> values, List<String> labels, ValueChanged<T> onChanged) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<T>(
          key: ValueKey('$label-$value'),
          initialValue: values.contains(value) ? value : values.first,
          dropdownColor: WorkspaceMenuStyle.surface(Theme.of(context).colorScheme),
          borderRadius: WorkspaceMenuStyle.borderRadius,
          isExpanded: true,
          decoration: InputDecoration(
              labelText: label, border: const OutlineInputBorder()),
          items: [
            for (var i = 0; i < values.length; i++)
              DropdownMenuItem(
                  value: values[i],
                  child: Text(labels[i],
                      maxLines: 2, overflow: TextOverflow.ellipsis))
          ],
          onChanged: (value) {
            if (value != null) onChanged(value);
          },
        ),
      );
}
