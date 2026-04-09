//+------------------------------------------------------------------+
//|                                    DeltaVolumeChannel_v2.mq5     |
//|              Canal de Delta e Volume Real - B3                    |
//+------------------------------------------------------------------+
#property copyright   "Delta Volume Channel v2.1"
#property version     "2.10"
#property description "Canal dinamico baseado em Delta (compra - venda) e Volume Real."
#property description "Compativel com WDO, WIN e contratos futuros da B3."
#property description " "
#property description "v2.1: Cores do painel separadas das cores da banda, painel customizavel"
#property description "(fonte, tamanho, posicao, canto). DRAW_FILLING, setas de cruzamento,"
#property description "prev_calculated otimizado, suavizacao de delta, cores customizaveis."
#property description "Use junto com DeltaVolumeHistogram.mq5 para ver o histograma de delta."
#property indicator_chart_window
#property indicator_buffers 7
#property indicator_plots   3

//--- Plot 0: Canal (DRAW_FILLING entre banda superior e inferior)
#property indicator_label1  "Banda Superior;Banda Inferior"
#property indicator_type1   DRAW_FILLING
#property indicator_color1  clrDodgerBlue,clrOrangeRed
#property indicator_style1  STYLE_SOLID
#property indicator_width1  1

//--- Plot 1: Linha Central (MA + deslocamento delta)
#property indicator_label2  "Centro"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrGold
#property indicator_style2  STYLE_DOT
#property indicator_width2  1

//--- Plot 2: Delta na Data Window
#property indicator_label3  "Delta"
#property indicator_type3   DRAW_NONE

//+------------------------------------------------------------------+
//| Parametros de Entrada                                             |
//+------------------------------------------------------------------+
input group           "=== Canal ==="
input int             InpPeriodo       = 20;        // Periodo do Canal
input double          InpMultATR       = 1.5;       // Multiplicador ATR (largura base)
input int             InpPeriodoATR    = 14;         // Periodo do ATR
input ENUM_MA_METHOD  InpMetodoMA      = MODE_EMA;   // Metodo da Media Movel

input group           "=== Delta ==="
input double          InpFatorDelta    = 1.0;       // Fator de Influencia do Delta
input bool            InpUsarTickReal  = true;       // Usar Ticks Reais (true) ou Aproximacao (false)
input int             InpSuavizDelta   = 3;          // Suavizacao EMA do Delta (1 = sem suavizacao)

input group           "=== Volume ==="
input double          InpVolMin        = 0.5;       // Ratio Volume Minimo
input double          InpVolMax        = 3.0;       // Ratio Volume Maximo

input group           "=== Cores da Banda ==="
input color           InpCorSuperior   = clrDodgerBlue;  // Cor Banda Superior / Fill Compra
input color           InpCorInferior   = clrOrangeRed;   // Cor Banda Inferior / Fill Venda
input color           InpCorCentro     = clrGold;        // Cor Linha Central
input int             InpLarguraLinha  = 1;               // Largura das Linhas
input bool            InpMostrarCentro = true;            // Mostrar Linha Central
input bool            InpMostrarSetas  = true;            // Mostrar Setas de Cruzamento
input int             InpTamanhoSeta   = 2;               // Tamanho da Seta (1-5)

input group           "=== Painel Informativo ==="
input bool            InpMostrarLabel    = true;              // Mostrar Painel Informativo
input color           InpCorPainelCompra = clrLime;           // Cor Texto Painel (Compra)
input color           InpCorPainelVenda  = clrRed;            // Cor Texto Painel (Venda)
input string          InpPainelFonte     = "Consolas";        // Fonte do Painel
input int             InpPainelTamanho   = 10;                // Tamanho da Fonte do Painel
input ENUM_BASE_CORNER InpPainelCanto    = CORNER_RIGHT_UPPER; // Canto do Painel
input int             InpPainelX         = 15;                // Distancia X do Painel (pixels)
input int             InpPainelY         = 20;                // Distancia Y do Painel (pixels)

input group           "=== Alertas ==="
input bool            InpAlertaCruzSup = false;     // Alertar cruzamento Banda Superior
input bool            InpAlertaCruzInf = false;     // Alertar cruzamento Banda Inferior
input bool            InpAlertaPush    = false;     // Enviar Push Notification
input bool            InpAlertaEmail   = false;     // Enviar Email

input group           "=== Exibicao ==="
input int             InpDiasExibir    = 1;          // Dias para exibir (0 = todos)

//+------------------------------------------------------------------+
//| Buffers do indicador                                              |
//+------------------------------------------------------------------+
double BufferSuperior[];     // Banda superior (plot 0, buffer 0)
double BufferInferior[];     // Banda inferior (plot 0, buffer 1)
double BufferCentro[];       // Linha central  (plot 1, buffer 2)
double BufferDeltaPlot[];    // Delta para Data Window (plot 2, buffer 3)
double BufferDelta[];        // Delta por barra bruto (calculo, buffer 4)
double BufferDeltaSmooth[];  // Delta suavizado (calculo, buffer 5)
double BufferVolRatio[];     // Ratio de volume (calculo, buffer 6)

//--- Handles de indicadores auxiliares
int g_handleMA  = INVALID_HANDLE;
int g_handleATR = INVALID_HANDLE;

//--- Prefixo unico para objetos graficos
string g_objPrefix;

//--- Controle de alertas (evitar repeticao)
datetime g_ultimoAlertaSup = 0;
datetime g_ultimoAlertaInf = 0;

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
   if(InpFatorDelta < 0)
     {
      Print("Erro: Fator de Delta deve ser >= 0");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpVolMin <= 0 || InpVolMin >= InpVolMax)
     {
      Print("Erro: VolMin deve ser > 0 e menor que VolMax");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpSuavizDelta < 1)
     {
      Print("Erro: Suavizacao do Delta deve ser >= 1");
      return(INIT_PARAMETERS_INCORRECT);
     }
   if(InpDiasExibir < 0)
     {
      Print("Erro: Dias para exibir deve ser >= 0");
      return(INIT_PARAMETERS_INCORRECT);
     }

//--- Configurar buffers
   SetIndexBuffer(0, BufferSuperior, INDICATOR_DATA);
   SetIndexBuffer(1, BufferInferior, INDICATOR_DATA);
   SetIndexBuffer(2, BufferCentro,   INDICATOR_DATA);
   SetIndexBuffer(3, BufferDeltaPlot, INDICATOR_DATA);
   SetIndexBuffer(4, BufferDelta,       INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufferDeltaSmooth, INDICATOR_CALCULATIONS);
   SetIndexBuffer(6, BufferVolRatio,    INDICATOR_CALCULATIONS);

//--- Inicializar buffers
   ArrayInitialize(BufferSuperior,   EMPTY_VALUE);
   ArrayInitialize(BufferInferior,   EMPTY_VALUE);
   ArrayInitialize(BufferCentro,     EMPTY_VALUE);
   ArrayInitialize(BufferDeltaPlot,  EMPTY_VALUE);
   ArrayInitialize(BufferDelta,      0.0);
   ArrayInitialize(BufferDeltaSmooth,0.0);
   ArrayInitialize(BufferVolRatio,   1.0);

//--- Aplicar cores customizaveis ao DRAW_FILLING
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 0, InpCorSuperior);
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, 1, InpCorInferior);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, InpLarguraLinha);

//--- Aplicar cor da linha central
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpCorCentro);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, InpLarguraLinha);

//--- Se nao mostrar centro, ocultar o plot
   if(!InpMostrarCentro)
      PlotIndexSetInteger(1, PLOT_DRAW_TYPE, DRAW_NONE);

//--- Criar handles para MA e ATR
   g_handleMA  = iMA(_Symbol, _Period, InpPeriodo, 0, InpMetodoMA, PRICE_CLOSE);
   g_handleATR = iATR(_Symbol, _Period, InpPeriodoATR);

   if(g_handleMA == INVALID_HANDLE || g_handleATR == INVALID_HANDLE)
     {
      Print("Erro ao criar handles dos indicadores auxiliares (MA/ATR)");
      return(INIT_FAILED);
     }

//--- Configurar nome do indicador
   string nome = "DeltaVolCh(" + IntegerToString(InpPeriodo) + "," +
                 DoubleToString(InpMultATR, 1) + "," +
                 DoubleToString(InpFatorDelta, 1) + ")";
   IndicatorSetString(INDICATOR_SHORTNAME, nome);
   IndicatorSetInteger(INDICATOR_DIGITS, _Digits);

//--- Barras iniciais sem desenho
   int min_bars = MathMax(InpPeriodo, InpPeriodoATR);
   PlotIndexSetInteger(0, PLOT_DRAW_BEGIN, min_bars);
   PlotIndexSetInteger(1, PLOT_DRAW_BEGIN, min_bars);
   PlotIndexSetInteger(2, PLOT_DRAW_BEGIN, min_bars);

//--- Criar prefixo unico para objetos graficos
   g_objPrefix = "DVC2_" + IntegerToString(ChartID()) + "_";

   Print("DeltaVolumeChannel v2.1 inicializado - ",
         "Periodo=", InpPeriodo,
         " ATR=", InpPeriodoATR,
         " MultATR=", DoubleToString(InpMultATR, 1),
         " FatorDelta=", DoubleToString(InpFatorDelta, 1),
         " Suaviz=", InpSuavizDelta,
         " TickReal=", InpUsarTickReal,
         " Dias=", InpDiasExibir);

   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Desinicializacao                                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- Remover todos os objetos graficos (labels e setas)
   ObjectsDeleteAll(0, g_objPrefix);
   ChartRedraw(0);

   if(g_handleMA  != INVALID_HANDLE)
      IndicatorRelease(g_handleMA);
   if(g_handleATR != INVALID_HANDLE)
      IndicatorRelease(g_handleATR);
  }

//+------------------------------------------------------------------+
//| Calcula o delta usando ticks reais (TICK_FLAG_BUY/SELL)          |
//+------------------------------------------------------------------+
double CalcularDeltaTicks(const datetime time_from, const datetime time_to)
  {
   MqlTick ticks[];

   int total = CopyTicksRange(_Symbol, ticks, COPY_TICKS_TRADE,
                              (long)time_from * 1000,
                              (long)time_to * 1000 - 1);

   if(total < 0)
     {
      Print("Aviso: CopyTicksRange falhou para barra ", TimeToString(time_from),
            " - erro ", GetLastError());
      return 0.0;
     }
   if(total == 0)
      return 0.0;

   double vol_compra = 0.0;
   double vol_venda  = 0.0;

   for(int i = 0; i < total; i++)
     {
      if((ticks[i].flags & TICK_FLAG_BUY) != 0)
         vol_compra += (double)ticks[i].volume;

      if((ticks[i].flags & TICK_FLAG_SELL) != 0)
         vol_venda += (double)ticks[i].volume;
     }

   return (vol_compra - vol_venda);
  }

//+------------------------------------------------------------------+
//| Calcula o delta por aproximacao (sem ticks reais)                |
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

   double posicao = (close_price - low_price) / range;
   double fator = (posicao - 0.5) * 2.0;

   return fator * (double)vol;
  }

//+------------------------------------------------------------------+
//| Busca binaria para encontrar indice por data                     |
//+------------------------------------------------------------------+
int EncontrarIndicePorData(const datetime &time[], const int rates_total,
                           const datetime data_alvo)
  {
   int lo = 0;
   int hi = rates_total - 1;
   int resultado = rates_total;

   while(lo <= hi)
     {
      int mid = (lo + hi) / 2;
      if(time[mid] >= data_alvo)
        {
         resultado = mid;
         hi = mid - 1;
        }
      else
         lo = mid + 1;
     }

   return resultado;
  }

//+------------------------------------------------------------------+
//| Desenha seta (triangulo) de cruzamento no grafico                |
//| codigo 217 = triangulo para cima, 218 = triangulo para baixo     |
//+------------------------------------------------------------------+
void DesenharSeta(const string nome, const datetime tempo, const double preco,
                  const int codigo_seta, const color cor, const int tamanho)
  {
   if(ObjectFind(0, nome) < 0)
     {
      ObjectCreate(0, nome, OBJ_ARROW, 0, tempo, preco);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nome, OBJPROP_BACK, false);
     }

   ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, codigo_seta);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, tamanho);
   ObjectSetInteger(0, nome, OBJPROP_TIME, 0, tempo);
   ObjectSetDouble(0, nome, OBJPROP_PRICE, 0, preco);
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

//--- Determinar data de inicio da exibicao
   datetime inicio_exibicao = 0;
   if(InpDiasExibir > 0)
     {
      MqlDateTime dt_now;
      TimeCurrent(dt_now);
      dt_now.hour = 0;
      dt_now.min  = 0;
      dt_now.sec  = 0;
      datetime inicio_hoje = StructToTime(dt_now);
      inicio_exibicao = inicio_hoje - (InpDiasExibir - 1) * 86400;
     }

//--- Encontrar o indice da primeira barra a exibir (busca binaria)
   int idx_inicio_exib = 0;
   if(InpDiasExibir > 0)
      idx_inicio_exib = EncontrarIndicePorData(time, rates_total, inicio_exibicao);

//--- Garantir minimo de barras para calculo
   int inicio = MathMax(idx_inicio_exib, min_bars);

//--- Limpar barras fora da exibicao e setas anteriores ao recarregar
   if(prev_calculated == 0)
     {
      for(int k = 0; k < inicio; k++)
        {
         BufferSuperior[k]  = EMPTY_VALUE;
         BufferInferior[k]  = EMPTY_VALUE;
         BufferCentro[k]    = EMPTY_VALUE;
         BufferDeltaPlot[k] = EMPTY_VALUE;
        }
      //--- Remover todas as setas anteriores
      ObjectsDeleteAll(0, g_objPrefix + "ARW_");
     }

//--- Determinar ponto de inicio do calculo (otimizacao prev_calculated)
   int calc_start;
   if(prev_calculated == 0)
      calc_start = inicio;
   else
      calc_start = MathMax(inicio, prev_calculated - 1);

//--- Constante para suavizacao EMA do delta
   double alpha_delta = (InpSuavizDelta > 1) ? 2.0 / (InpSuavizDelta + 1.0) : 1.0;

//--- Offset para posicionar setas acima/abaixo dos candles
   double seta_offset = 0;
   if(rates_total > 0 && atr_vals[rates_total - 1] != EMPTY_VALUE && atr_vals[rates_total - 1] > 0)
      seta_offset = atr_vals[rates_total - 1] * 0.3;
   else
      seta_offset = _Point * 50;

//--- Loop principal de calculo
   for(int i = calc_start; i < rates_total; i++)
     {
      //=== 1. CALCULAR DELTA DA BARRA ===
      if(InpUsarTickReal)
        {
         datetime t_from = time[i];
         datetime t_to   = (i < rates_total - 1) ? time[i + 1] : TimeCurrent();
         BufferDelta[i]  = CalcularDeltaTicks(t_from, t_to);
        }
      else
        {
         BufferDelta[i] = CalcularDeltaAprox(open[i], close[i],
                                             high[i], low[i], volume[i]);
        }

      //=== 2. SUAVIZAR DELTA (EMA opcional) ===
      if(InpSuavizDelta <= 1 || i == 0)
        {
         BufferDeltaSmooth[i] = BufferDelta[i];
        }
      else
        {
         double prev_smooth = (i > 0) ? BufferDeltaSmooth[i - 1] : BufferDelta[i];
         BufferDeltaSmooth[i] = alpha_delta * BufferDelta[i] +
                                (1.0 - alpha_delta) * prev_smooth;
        }

      BufferDeltaPlot[i] = BufferDeltaSmooth[i];

      //=== 3. CALCULAR DELTA ACUMULADO E VOLUME TOTAL ===
      double delta_acum = 0.0;
      double vol_total  = 0.0;

      int lookback = MathMin(InpPeriodo, i + 1);
      for(int j = 0; j < lookback; j++)
        {
         delta_acum += BufferDeltaSmooth[i - j];
         vol_total  += (double)volume[i - j];
        }

      //=== 4. NORMALIZAR DELTA PELO VOLUME ===
      double delta_norm = 0.0;
      if(vol_total > 0.0)
         delta_norm = delta_acum / vol_total;

      //=== 5. CALCULAR RATIO DE VOLUME ===
      double vol_medio = vol_total / lookback;
      double vol_ratio = 1.0;
      if(vol_medio > 0.0)
         vol_ratio = (double)volume[i] / vol_medio;

      vol_ratio = MathMax(InpVolMin, MathMin(vol_ratio, InpVolMax));
      BufferVolRatio[i] = vol_ratio;

      //=== 6. CALCULAR O CANAL ===
      double ma  = ma_vals[i];
      double atr = atr_vals[i];

      double largura = atr * InpMultATR * MathSqrt(vol_ratio);
      double deslocamento = delta_norm * atr * InpFatorDelta * MathSqrt((double)InpPeriodo);

      double central    = ma + deslocamento;
      BufferCentro[i]   = central;
      BufferSuperior[i] = central + largura;
      BufferInferior[i] = central - largura;

      //=== 7. DESENHAR SETAS DE CRUZAMENTO (triangulos) ===
      if(InpMostrarSetas && i > inicio)
        {
         //--- Cruzou banda superior para cima (sobrecompra)
         //--- Triangulo para baixo (218) vermelho ACIMA do candle
         if(close[i] > BufferSuperior[i] && close[i - 1] <= BufferSuperior[i - 1])
           {
            string nome = g_objPrefix + "ARW_DN_" + IntegerToString((long)time[i]);
            DesenharSeta(nome, time[i], high[i] + seta_offset,
                         218, InpCorInferior, InpTamanhoSeta);
           }

         //--- Cruzou banda inferior para baixo (sobrevenda)
         //--- Triangulo para cima (217) azul ABAIXO do candle
         if(close[i] < BufferInferior[i] && close[i - 1] >= BufferInferior[i - 1])
           {
            string nome = g_objPrefix + "ARW_UP_" + IntegerToString((long)time[i]);
            DesenharSeta(nome, time[i], low[i] - seta_offset,
                         217, InpCorSuperior, InpTamanhoSeta);
           }
        }
     }

//--- Verificar alertas na ultima barra fechada
   if(rates_total >= 2)
     {
      int last = rates_total - 2;
      int prev = last - 1;

      if(prev >= inicio && last >= inicio)
        {
         if(InpAlertaCruzSup &&
            close[last] > BufferSuperior[last] &&
            close[prev] <= BufferSuperior[prev] &&
            time[last] > g_ultimoAlertaSup)
           {
            g_ultimoAlertaSup = time[last];
            string msg = _Symbol + " " + EnumToString(_Period) +
                         " - Preco cruzou BANDA SUPERIOR do DeltaVolChannel";
            DispararAlerta(msg);
           }

         if(InpAlertaCruzInf &&
            close[last] < BufferInferior[last] &&
            close[prev] >= BufferInferior[prev] &&
            time[last] > g_ultimoAlertaInf)
           {
            g_ultimoAlertaInf = time[last];
            string msg = _Symbol + " " + EnumToString(_Period) +
                         " - Preco cruzou BANDA INFERIOR do DeltaVolChannel";
            DispararAlerta(msg);
           }
        }
     }

//--- Atualizar label informativo
   if(InpMostrarLabel && rates_total > 0)
     {
      int idx = rates_total - 1;
      AtualizarLabel(BufferDeltaSmooth[idx], BufferVolRatio[idx],
                     BufferSuperior[idx], BufferInferior[idx]);
     }

   return rates_total;
  }

//+------------------------------------------------------------------+
//| Dispara alerta em todos os canais habilitados                    |
//+------------------------------------------------------------------+
void DispararAlerta(const string mensagem)
  {
   Alert(mensagem);

   if(InpAlertaPush)
      SendNotification(mensagem);

   if(InpAlertaEmail)
      SendMail("DeltaVolumeChannel Alerta", mensagem);
  }

//+------------------------------------------------------------------+
//| Atualiza label informativo (painel) com cores independentes      |
//+------------------------------------------------------------------+
void AtualizarLabel(const double delta_val,
                    const double vol_ratio,
                    const double banda_sup,
                    const double banda_inf)
  {
   string nome_label = g_objPrefix + "INFO";

   string direcao = (delta_val >= 0) ? "COMPRA" : "VENDA";
   color cor_texto = (delta_val >= 0) ? InpCorPainelCompra : InpCorPainelVenda;

   string texto = StringFormat("Delta: %+.0f | VolRatio: %.2f | %s | Sup: %s | Inf: %s",
                               delta_val, vol_ratio, direcao,
                               DoubleToString(banda_sup, _Digits),
                               DoubleToString(banda_inf, _Digits));

//--- Determinar anchor baseado no canto escolhido
   ENUM_ANCHOR_POINT anchor_point;
   switch(InpPainelCanto)
     {
      case CORNER_RIGHT_UPPER: anchor_point = ANCHOR_RIGHT_UPPER; break;
      case CORNER_RIGHT_LOWER: anchor_point = ANCHOR_RIGHT_LOWER; break;
      case CORNER_LEFT_UPPER:  anchor_point = ANCHOR_LEFT_UPPER;  break;
      case CORNER_LEFT_LOWER:  anchor_point = ANCHOR_LEFT_LOWER;  break;
      default:                 anchor_point = ANCHOR_RIGHT_UPPER; break;
     }

   if(ObjectFind(0, nome_label) < 0)
     {
      ObjectCreate(0, nome_label, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nome_label, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome_label, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nome_label, OBJPROP_BACK, false);
     }

//--- Atualizar propriedades do painel (permite mudanca em tempo real)
   ObjectSetInteger(0, nome_label, OBJPROP_CORNER, InpPainelCanto);
   ObjectSetInteger(0, nome_label, OBJPROP_ANCHOR, anchor_point);
   ObjectSetInteger(0, nome_label, OBJPROP_XDISTANCE, InpPainelX);
   ObjectSetInteger(0, nome_label, OBJPROP_YDISTANCE, InpPainelY);
   ObjectSetString(0, nome_label, OBJPROP_FONT, InpPainelFonte);
   ObjectSetInteger(0, nome_label, OBJPROP_FONTSIZE, InpPainelTamanho);

   ObjectSetString(0, nome_label, OBJPROP_TEXT, texto);
   ObjectSetInteger(0, nome_label, OBJPROP_COLOR, cor_texto);

   ChartRedraw(0);
  }
//+------------------------------------------------------------------+
