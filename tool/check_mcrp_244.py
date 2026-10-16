#!/usr/bin/env python3
"""Verifica a integração MCRP sem substituir dart analyze/flutter test."""
from pathlib import Path
root=Path(__file__).resolve().parents[1]
client=(root/'lib/services/mcrp_client.dart').read_text()
screen=(root/'lib/screens/mcrp_camera_screen.dart').read_text()
home=(root/'lib/screens/home_screen_redesign.dart').read_text()
legacy=(root/'lib/services/remote_camera_pairing_service.dart').read_text()
protocol=(root/'docs/MCRP_V1.md').read_text()
checks={
'validação IPv4':"_isLocalIpv4" in client and "[0-9a-f]{32}" in client,
'sem domínio arbitrário':"uri.port != 8765" in client and "uri.scheme != 'http'" in client,
'consulta versão MCRP':"result['protocol'] != 'mcrp'" in client and "result['version'] != 1" in client,
'rotas de mídia':"mcrp/media" in client and "mediaFile(String id)" in client,
'download com tamanho':"received != item.size" in client,
'autorização POST':"_http.postUrl" in client,
'viewer JPEG':"class _McrpMjpegView" in screen,
'viewer H.264':"class _McrpVlcView" in screen and ":demux=h264" in screen,
'QR do Minha Câmera':"MobileScanner" in screen and "McrpAddress.parse(raw)" in screen,
'controles':all(x in screen for x in ('record/', 'eco/', 'photo', 'camera/', 'quality/', 'fps/', 'codec/')),
'central multimídia':"_loadMedia" in screen and "_download" in screen,
'entrada por Câmeras':"McrpCameraScreen" in (root/'lib/screens/multi_camera_screen.dart').read_text() and "McrpCameraScreen" in home,
'pareamento Vigia antigo':"static const String scheme = 'vigiaia';" in legacy,
'especificação':"MCRP) v1" in protocol,
}
for label,ok in checks.items():
 if not ok:raise SystemExit(f'ERRO MCRP: {label}')
print('MCRP Vigia IA: %d contratos preventivos aprovados (nao substitui Flutter).'%len(checks))
