/// Modo visual do mapa. Nao equivale ao papel do aparelho (AppLaunchMode)
/// nem ao estado de gravacao, navegacao, camera ou ESP32.
enum MapWorkspaceMode {
  explore('Explorar', 'Mapa, camadas e pontos de interesse.'),
  ride('Pedalar', 'Percurso, velocidade e informacoes de cicloviagem.'),
  navigate('Navegar', 'Destino, rotas e orientacao.'),
  monitor('Monitorar', 'Acesso opcional a cameras, IA e alertas.');

  const MapWorkspaceMode(this.label, this.description);
  final String label;
  final String description;
}
