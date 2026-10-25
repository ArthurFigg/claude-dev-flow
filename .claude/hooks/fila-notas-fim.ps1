# Gancho Stop da fila de propostas. No fim de cada resposta, procura sinais pontuais
# (correcao dele, recusa, desfazer, nota da IA) que nenhum commit mandou avaliar.
# Existe porque o que vem DEPOIS do ultimo commit o fila-sinais-commit.ps1 nao ve:
# no teste de 24/10, 4 de 9 notas se perdiam e uma correcao com git revert passou batido.
# Sinais que somam no trecho (teste refeito, arquivo 3x, conversa longa) ficam so no commit.

. (Join-Path $PSScriptRoot 'fila-sinais-comum.ps1')

$entrada = [Console]::In.ReadToEnd() | ConvertFrom-Json

function Fica-Quieto {
    Write-Output "{}"
    exit 0
}

# Ja esta continuando por causa deste gancho: nao segura de novo (evita laco).
if ($entrada.stop_hook_active) { Fica-Quieto }

$caminho = $entrada.transcript_path
if (-not $caminho -or -not (Test-Path $caminho)) { Fica-Quieto }

$estado = Ler-EstadoFila $entrada.session_id
$eventos = Ler-EventosFila $caminho
$r = Achar-SinaisFila $eventos 0 $estado.Ja

$sinais = @(Sinais-PontuaisFila $r)
if ($sinais.Count -eq 0) { Fica-Quieto }
$r.Chaves | Add-Content $estado.Arquivo -Encoding UTF8

$motivo = "[fila-propostas] Sinais ainda sem avaliacao nesta sessao:`n- " + ($sinais -join "`n- ") +
    "`nSessao atual: $($entrada.session_id)" +
    "`nAvalie AGORA com a skill propor-melhoria: revise so o trecho perto de cada sinal, registre pelo script e termine com o aviso no formato da skill. Se nenhum sinal tem a ver com arquivo do fluxo (ex.: pedido normal de trabalho), termine sem falar da fila."

[ordered]@{ decision = 'block'; reason = $motivo } | ConvertTo-Json -Compress
