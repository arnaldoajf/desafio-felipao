# WDO Smart Money Concepts - Indicador MQL5 para MetaTrader 5

Indicador completo de **Smart Money Concepts (SMC)** projetado para operar **WDO (Mini Dólar)** no timeframe de **5 minutos** na B3 (mercado brasileiro).

## Funcionalidades

### 1. BOS (Break of Structure)
- Detecta rompimento de Swing High/Low na **mesma direção** da tendência (continuação)
- Linha tracejada + label "BOS↑" ou "BOS↓"
- Cores configuráveis (padrão: azul para bull, vermelho para bear)

### 2. CHOCH (Change of Character)
- Detecta rompimento de Swing High/Low **contra** a tendência atual (reversão)
- Linha tracejada + label "CHOCH↑" ou "CHOCH↓"
- Cores configuráveis (padrão: verde para bull, magenta para bear)

### 3. Imbalance / Fair Value Gap (FVG)
- Identifica gaps de preço (3 candles onde `high[candle1] < low[candle3]` ou vice-versa)
- Retângulos preenchidos com transparência marcando a zona de imbalance
- **Mitigação automática**: retângulos removidos quando o preço retorna à zona
- Máximo de barras configurável para exibição

### 4. Order Block (OB)
- Último candle **contrário** antes do rompimento (BOS/CHOCH)
- OB Bullish = último candle bearish antes de um BOS/CHOCH bullish
- OB Bearish = último candle bullish antes de um BOS/CHOCH bearish
- Retângulos com zona high-low do candle
- Mitigação visual (muda para cinza quando o preço atinge a zona)

### 5. Agressão via Times & Trades / DOM
- Análise tick-a-tick classificando **agressão compradora vs vendedora**
- Classificação por flags de tick (`TICK_FLAG_BUY` / `TICK_FLAG_SELL`)
- Fallback inteligente: compara `last` vs `bid/ask` quando flags não disponíveis
- Exibe delta (A+ compra / P- venda / Δ delta) por candle
- **Limiar mínimo** configurável para filtrar ruído
- **Book de ofertas (DOM)**: mostra profundidade Bid vs Ask no canto do gráfico

## Parâmetros de Entrada

| Grupo | Parâmetro | Padrão | Descrição |
|-------|-----------|--------|-----------|
| Estrutura | `InpSwingLen` | 5 | Lookback para detecção de Swing High/Low |
| Estrutura | `InpShowBOS` | true | Mostrar BOS no gráfico |
| Estrutura | `InpShowCHOCH` | true | Mostrar CHOCH no gráfico |
| Imbalance | `InpShowImbalance` | true | Mostrar zonas de Imbalance/FVG |
| Imbalance | `InpImbMaxBars` | 50 | Máximo de barras para extensão do retângulo |
| Imbalance | `InpImbMitigated` | true | Remover FVG quando mitigado |
| Order Block | `InpShowOB` | true | Mostrar Order Blocks |
| Order Block | `InpOBMaxBars` | 80 | Máximo de barras para extensão do OB |
| Times & Trades | `InpShowAggression` | true | Mostrar análise de agressão |
| Times & Trades | `InpAggPeriod` | 5 | Período de agregação |
| Times & Trades | `InpDeltaThreshold` | 50 | Delta mínimo para exibir label |
| Alertas | `InpAlertBOS` | true | Alerta sonoro em BOS |
| Alertas | `InpAlertCHOCH` | true | Alerta sonoro em CHOCH |
| Alertas | `InpAlertOB` | true | Alerta sonoro em Order Block |
| Alertas | `InpAlertPush` | false | Enviar push notification |

## Instalação

1. Copie o arquivo `WDO_SmartMoney.mq5` para a pasta `MQL5/Indicators/` do seu MetaTrader 5
2. No MetaTrader 5, abra o **MetaEditor** e compile o indicador (F7)
3. Arraste o indicador para o gráfico de **WDO** no timeframe **M5**
4. Configure os parâmetros conforme sua preferência

## Legenda Visual

| Elemento | Cor Padrão | Significado |
|----------|-----------|-------------|
| Seta azul + "BOS↑" | Azul | Break of Structure Bullish |
| Seta vermelha + "BOS↓" | Vermelho | Break of Structure Bearish |
| Seta verde + "CHOCH↑" | Verde | Change of Character Bullish |
| Seta magenta + "CHOCH↓" | Magenta | Change of Character Bearish |
| Retângulo azul escuro | Azul escuro | Imbalance/FVG Bullish |
| Retângulo vermelho escuro | Vermelho escuro | Imbalance/FVG Bearish |
| Retângulo verde escuro | Verde escuro | Order Block Bullish |
| Retângulo vinho | Vinho | Order Block Bearish |
| "A+" / "P-" / "Δ" | Azul/Vermelho | Agressão compradora/vendedora e delta |

## Requisitos

- MetaTrader 5 (build 2361+)
- Conta em corretora brasileira com acesso a WDO
- Dados de tick em tempo real (para Times & Trades)
- Book de ofertas habilitado (para DOM)

## Notas

- O indicador foi otimizado para **WDO no M5**, mas pode ser usado em outros ativos e timeframes
- A análise de agressão via Times & Trades requer dados de tick em tempo real
- Para melhor performance, ajuste `InpImbMaxBars` e `InpOBMaxBars` conforme necessário
