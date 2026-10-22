# Comprueba que un sitio del laboratorio es el correcto y está funcionando: código HTTP Y marcador esperado.
# Solo lee: hace una petición GET y no cambia configuración ni datos.
# Uso (PowerShell en el PC):
#   powershell -ExecutionPolicy Bypass -File .\comprobar-sitio.ps1 -Url http://ensayo.abaco.test/ -Marcador "ABACO ENSAYO ENTREGA A"
# Salida: OK (código 0) o FALLO con el motivo (código 1).
param(
    [Parameter(Mandatory = $true)] [string] $Url,
    [Parameter(Mandatory = $true)] [string] $Marcador
)

# Sin proxy y con 5 s de límite: la respuesta tiene que venir del servidor, no de un intermediario
$salida = & curl.exe -s --noproxy "*" --max-time 5 -w "`n%{http_code} %{size_download} %{remote_ip}" $Url

# La última línea la añade -w: código, bytes recibidos e IP a la que se conectó
$codigo, $bytes, $ip = ($salida | Select-Object -Last 1) -split ' '
$cuerpo = ($salida | Select-Object -SkipLast 1) -join "`n"

# Contains distingue mayúsculas: busca el marcador exacto, no "abaco" en cualquier parte
$conMarcador = $cuerpo.Contains($Marcador)
$titulo = if ($cuerpo -match '<title>(.*?)</title>') { $Matches[1] } else { '(sin título)' }

Write-Output "Sitio:    $Url"
Write-Output "Conectó:  $ip"
Write-Output "Código:   $codigo"
Write-Output "Tamaño:   $bytes bytes"
Write-Output "Título:   $titulo"
Write-Output ("Marcador: '$Marcador' " + $(if ($conMarcador) { 'encontrado' } else { 'NO encontrado' }))

if ($codigo -eq '200' -and $conMarcador) {
    Write-Output 'RESULTADO: OK - responde 200 y es la página esperada'
    exit 0
}
elseif ($codigo -eq '200') {
    Write-Output 'RESULTADO: FALLO - responde 200 pero NO es la página esperada (¿otro sitio? revisa el nombre pedido)'
    exit 1
}
elseif ($codigo -eq '000') {
    Write-Output 'RESULTADO: FALLO - sin respuesta (nombre, red, servicio caído o tiempo agotado)'
    exit 1
}
else {
    Write-Output "RESULTADO: FALLO - código $codigo"
    exit 1
}
