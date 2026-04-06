//+------------------------------------------------------------------+
//|                                       DeltaVolumeChannel.mq5     |
//|              Canal de Delta e Volume Real para WDO B3             |
//+------------------------------------------------------------------+
#property copyright   "Delta Volume Channel - WDO B3"
#property version     "1.00"
#property description "Canal dinamico baseado em Delta (compra - venda) e Volume Real."
#property description "Desenvolvido para WDO e contratos futuros da B3."
#property description " "
#property description "O delta desloca o canal na direcao da pressao dominante."
#property description "O volume real ajusta a largura do canal dinamicamente."
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   3

//--- Plot 0: Banda Superior
#property indicator_label1  "Banda Superior"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 1: Linha Central (colorida pelo delta)
#property indicator_label2  "Linha Central"
#property indicator_type2   DRAW_COLOR_LINE
#property indicator_color2  clrLime,clrRed,clrGold
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 2: Banda Inferior
#property indicator_label3  "Banda Inferior"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrOrangeRed
#property indicator_style3  STYLE_SOLID
#property indicator_width3  2

//+------------------------------------------------------------------+
//| Parametros de Entrada                                             |
//+------------------------------------------------------------------+
input group           "=== Canal ==="
input int             InpPeriodo       = 20;       // Periodo do Canal
input double          InpMultATR       = 1.5;      // Multiplicador ATR (largura base)
input int             InpPeriodoATR    = 14;        // Periodo do ATR
input ENUM_MA_METHOD  InpMetodoMA      = MODE_EMA;  // Metodo da Media Movel

input group           "=== Delta ==="
input double          InpFatorDelta    = 1.0;      // Fator de Influencia do Delta
input bool            InpUsarTickReal  = true;      // Usar Ticks Reais (true) ou Aproximacao (false)

input group           "=== Volume ==="
input double          InpVolMin        = 0.5;      // Ratio Volume Minimo
input double          InpVolMax        = 3.0;      // Ratio Volume Maximo

//+------------------------------------------------------------------+
//| Buffers do indicador                                              |
//+------------------------------------------------------------------+
double BufferSuperior[];     // Banda superior
double BufferCentral[];      // Linha central
double BufferCentralCor[];   // Indice de cor da linha central
double BufferInferior[];     // Banda inferior
double BufferDelta[];        // Delta por barra (calculo)
double BufferDeltaCum[];     // Delta acumulado (calculo)
double BufferVolRatio[];     // Ratio de volume (calculo)

//--- Handles de indicadores auxiliares
int g_handleMA  = INVALID_HANDLE;
int g_handleATR = INVALID_HANDLE;

//+------------------------------------------------------------------+
//| Inicializacao do indicador                                        |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- Validar parametros
   if(InpPeriodo < 2)
     {
      Print("Erro: Periodo do canal deve ser >= 2");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpPeriodoATR < 1)
     {
      Print("Erro: Periodo do ATR deve ser >= 1");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpMultATR <= 0)
     {
      Print("Erro: Multiplicador ATR deve ser > 0");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Configurar buffers (ordem: plots primeiro, depois calculos)
   SetIndexBuffer(0, BufferSuperior,   INDICATOR_DATA);
   SetIndexBuffer(1, BufferCentral,    INDICATOR_DATA);
   SetIndexBuffer(2, BufferCentralCor, INDICATOR_COLOR_INDEX);
   SetIndexBuffer(3, BufferInferior,   INDICATOR_DATA);
   SetIndexBuffer(4, BufferDelta,      INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferDeltaCum,   INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferVolRatio,   INDICATOR_CALCULATIONS);

//--- Inicializar buffers com EMPTY_VALUE
   ArrayInitialize(BufferSuperior, EMPTY_VALUE);
   ArrayInitialize(BufferCentral,  EMPTY_VALUE);
   ArrayInitialize(BufferInferior, EMPTY_VALUE);
   ArrayInitialize(BufferDelta,    0.0);
   ArrayInitialize(BufferDeltaCum, 0.0);
   ArrayInitialize(BufferVolRatio, 1.0);

//--- Criar handles para MA e ATR
   g_handleMA  = iMA(_Symbol, _Period, InpPeriodo, 0, InpMetodoMA, PRICE_CLOSE);
   g_handleATR = iATR(_Symbol, _Period, InpPeriodoATR);

   if(g_handleMA == INVALID_HANDLE || g_handleATR == INVALID_HANDLE)
     {
      Print("Erro ao criar handles dos indicadores auxiliares (MA/ATR)");
      return(INIT_FAILED);
     }

//--- Configurar nome do indicador na janela de dados
   string nome = "DeltaVolCh(" + IntegerToString(InpPeriodo) + "," +
                 DoubleToString(InpMultATR, 1) + "," +
                 DoubleToString(InpFatorDelta, 1) + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, nome);

//--- Configurar precisao de exibicao
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Barras iniciais sem desenho
   int min_bars = MathMax(InpPeriodo, InpPeriodoATR);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars);

   Print("DeltaVolumeChannel inicializado com sucesso - ",
         "Periodo=", InpPeriodo,
         " ATR=", InpPeriodoATR,
         " MultATR=", DoubleToString(InpMultATR, 1),
         " FatorDelta=", DoubleToString(InpFatorDelta, 1),
         " TickReal=", InpUsarTickReal);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Desinicializacao                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(g_handleMA  != INVALID_HANDLE)
      IndicatorRelease(g_handleMA);
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);
  }

//+------------------------------------------------------------------+
//| Calcula o delta usando ticks reais (TICK_FLAG_BUY/SELL)          |
//| Retorna: volume_compra - volume_venda                            |
//+------------------------------------------------------------------+
double CalcularDeltaTicks(const datetime time_from, const datetime time_to)
  {
   MqlTick ticks[];

//--- Copiar ticks de trade no intervalo da barra (timestamps em milissegundos)
   int total = CopyTicksRange(_Symbol, ticks, COPY_TICKS_TRADE,
                              (long)time_from * 1000,
                              (long)time_to * 1000 - 1);

   if(total <= 0)
      return 0.0;

   double vol_compra = 0.0;
   double vol_venda  = 0.0;

   for(int i = 0; i < total; i++)
     {
      //--- Verificar flags de agressao
      if((ticks[i].flags & TICK_FLAG_BUY) != 0)
         vol_compra += (double)ticks[i].volume;

      if((ticks[i].flags & TICK_FLAG_SELL) != 0)
         vol_venda += (double)ticks[i].volume;
     }

   return (vol_compra - vol_venda);
  }

//+------------------------------------------------------------------+
//| Calcula o delta por aproximacao (sem ticks reais)                |
//| Se close > open: delta positivo (compra)                         |
//| Se close < open: delta negativo (venda)                          |
//| Se close == open: delta baseado na relacao com barra anterior    |
//+------------------------------------------------------------------+
double CalcularDeltaAprox(const double open_price,
                          const double close_price,
                          const double high_price,
                          const double low_price,
                          const long vol)
  {
   if(vol == 0)
      return 0.0;

   double range = high_price - low_price;
   if(range <= 0)
      return 0.0;

//--- Posicao do fechamento dentro da barra (0 = fundo, 1 = topo)
   double posicao = (close_price - low_price) / range;

//--- Delta proporcional: mais perto do topo = mais compra
//--- posicao 0.5 = neutro, > 0.5 = compra, < 0.5 = venda
   double fator = (posicao - 0.5) * 2.0;  // Range: -1.0 a +1.0

   return fator * (double)vol;
  }

//+------------------------------------------------------------------+
//| Calculo principal do indicador                                    |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
  {
//--- Verificar minimo de barras
   int min_bars = MathMax(InpPeriodo, InpPeriodoATR) + 1;
   if(rates_total < min_bars)
      return 0;

//--- Copiar valores da MA e ATR
   double ma_vals[];
   double atr_vals[];

   if(CopyBuffer(g_handleMA,  0, 0, rates_total, ma_vals)  <= 0)
      return 0;
   if(CopyBuffer(g_handleATR, 0, 0, rates_total, atr_vals) <= 0)
      return 0;

//--- Determinar ponto de inicio do calculo
   int inicio;
   if(prev_calculated > 0)
      inicio = prev_calculated - 1;
   else
      inicio = min_bars;

//--- Loop principal de calculo
   for(int i = inicio; i < rates_total; i++)
     {
      //=== 1. CALCULAR DELTA DA BARRA ===
      if(InpUsarTickReal)
        {
         //--- Usar ticks reais com flags de compra/venda
         datetime t_from = time[i];
         datetime t_to   = (i < rates_total - 1) ? time[i + 1] : TimeCurrent();
         BufferDelta[i]  = CalcularDeltaTicks(t_from, t_to);
        }
      else
        {
         //--- Usar aproximacao baseada na posicao do fechamento
         BufferDelta[i] = CalcularDeltaAprox(open[i], close[i],
                                             high[i], low[i], volume[i]);
        }

      //=== 2. CALCULAR DELTA ACUMULADO E VOLUME MEDIO ===
      double delta_acum = 0.0;
      double vol_total  = 0.0;

      int lookback = MathMin(InpPeriodo, i + 1);
      for(int j = 0; j < lookback; j++)
        {
         delta_acum += BufferDelta[i - j];
         vol_total  += (double)volume[i - j];
        }

      BufferDeltaCum[i] = delta_acum;

      //=== 3. NORMALIZAR DELTA PELO VOLUME ===
      double delta_norm = 0.0;
      if(vol_total > 0.0)
         delta_norm = delta_acum / vol_total;  // Varia aproximadamente entre -1 e 1

      //=== 4. CALCULAR RATIO DE VOLUME (atual / media) ===
      double vol_medio = vol_total / lookback;
      double vol_ratio = 1.0;
      if(vol_medio > 0.0)
         vol_ratio = (double)volume[i] / vol_medio;

      //--- Limitar o ratio para evitar extremos
      vol_ratio = MathMax(InpVolMin, MathMin(vol_ratio, InpVolMax));
      BufferVolRatio[i] = vol_ratio;

      //=== 5. CALCULAR O CANAL ===
      double ma  = ma_vals[i];
      double atr = atr_vals[i];

      //--- Largura base: ATR * multiplicador, modulada pelo volume
      //--- sqrt() suaviza o efeito do volume para evitar expansoes bruscas
      double largura = atr * InpMultATR * MathSqrt(vol_ratio);

      //--- Deslocamento do canal baseado no delta normalizado
      //--- sqrt(periodo) normaliza o efeito para diferentes periodos
      double deslocamento = delta_norm * atr * InpFatorDelta * MathSqrt((double)InpPeriodo);

      //--- Calcular as tres linhas do canal
      BufferCentral[i]  = ma + deslocamento;
      BufferSuperior[i] = BufferCentral[i] + largura;
      BufferInferior[i] = BufferCentral[i] - largura;

      //=== 6. COR DA LINHA CENTRAL BASEADA NO DELTA ===
      if(delta_acum > 0)
         BufferCentralCor[i] = 0;   // Verde (compra dominante)
      else if(delta_acum < 0)
         BufferCentralCor[i] = 1;   // Vermelho (venda dominante)
      else
         BufferCentralCor[i] = 2;   // Dourado (neutro)
     }

   return rates_total;
  }
//+------------------------------------------------------------------+
