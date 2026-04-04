//+------------------------------------------------------------------+
//|                                              WDO_SmartMoney.mq5  |
//|                        Indicador Smart Money Concepts para WDO   |
//|                        Imbalance, Order Block, BOS/CHOCH,        |
//|                        Agressao via Times & Trades / DOM          |
//|                        Timeframe: M5                              |
//+------------------------------------------------------------------+
#property copyright   "Arnaldo Felipe"
#property link        "https://github.com/arnaldoajf"
#property version     "1.00"
#property description "Smart Money Concepts: Imbalance, Order Block, BOS/CHOCH + Times and Trades para WDO (M5)"
#property indicator_chart_window
#property indicator_buffers 6
#property indicator_plots   4

//--- Plot 1: BOS Arrow Up
#property indicator_label1  "BOS Bull"
#property indicator_type1   DRAW_ARROW
#property indicator_color1  clrDodgerBlue
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2

//--- Plot 2: BOS Arrow Down
#property indicator_label2  "BOS Bear"
#property indicator_type2   DRAW_ARROW
#property indicator_color2  clrOrangeRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2

//--- Plot 3: CHOCH Arrow Up
#property indicator_label3  "CHOCH Bull"
#property indicator_type3   DRAW_ARROW
#property indicator_color3  clrLime
#property indicator_style3  STYLE_SOLID
#property indicator_width3  3

//--- Plot 4: CHOCH Arrow Down
#property indicator_label4  "CHOCH Bear"
#property indicator_type4   DRAW_ARROW
#property indicator_color4  clrMagenta
#property indicator_style4  STYLE_SOLID
#property indicator_width4  3

//+------------------------------------------------------------------+
//| Inputs                                                            |
//+------------------------------------------------------------------+
//--- === Estrutura de Mercado (BOS/CHOCH) ===
input int    InpSwingLen        = 5;        // Lookback para Swing High/Low
input bool   InpShowBOS         = true;     // Mostrar BOS
input bool   InpShowCHOCH       = true;     // Mostrar CHOCH
input color  InpBOSBullColor    = clrDodgerBlue;  // Cor BOS Bullish
input color  InpBOSBearColor    = clrOrangeRed;   // Cor BOS Bearish
input color  InpCHOCHBullColor  = clrLime;        // Cor CHOCH Bullish
input color  InpCHOCHBearColor  = clrMagenta;     // Cor CHOCH Bearish

//--- === Imbalance (Fair Value Gap) ===
input bool   InpShowImbalance   = true;     // Mostrar Imbalance/FVG
input color  InpImbBullColor    = C'30,80,180';   // Cor Imbalance Bullish
input color  InpImbBearColor    = C'180,50,50';   // Cor Imbalance Bearish
input int    InpImbMaxBars      = 50;       // Max barras para exibir Imbalance
input bool   InpImbMitigated    = true;     // Remover quando mitigado

//--- === Order Block ===
input bool   InpShowOB          = true;     // Mostrar Order Block
input color  InpOBBullColor     = C'20,120,60';   // Cor OB Bullish
input color  InpOBBearColor     = C'160,40,40';   // Cor OB Bearish
input int    InpOBMaxBars       = 80;       // Max barras para exibir OB

//--- === Times & Trades (Agressao) ===
input bool   InpShowAggression  = true;     // Mostrar Agressao (Times & Trades)
input int    InpAggPeriod       = 5;        // Periodo de agregacao (barras)
input color  InpAggBuyColor     = clrDodgerBlue;  // Cor Agressao Compradora
input color  InpAggSellColor    = clrOrangeRed;   // Cor Agressao Vendedora
input int    InpAggFontSize     = 8;        // Tamanho da fonte agressao
input int    InpDeltaThreshold  = 50;       // Limiar minimo de delta para exibir

//--- === Alertas ===
input bool   InpAlertBOS        = true;     // Alerta em BOS
input bool   InpAlertCHOCH      = true;     // Alerta em CHOCH
input bool   InpAlertOB         = true;     // Alerta em Order Block
input bool   InpAlertPush       = false;    // Enviar Push Notification

//+------------------------------------------------------------------+
//| Enums e Structs                                                   |
//+------------------------------------------------------------------+
enum ENUM_TREND { TREND_NONE, TREND_BULL, TREND_BEAR };

struct SwingPoint
{
   double   price;
   int      bar_index;
   datetime time;
   bool     is_high;     // true = swing high, false = swing low
   bool     broken;
};

struct OrderBlock
{
   double   high;
   double   low;
   double   open;
   double   close;
   datetime time_start;
   datetime time_end;
   int      bar_index;
   bool     is_bullish;
   bool     active;
   string   obj_name;
};

struct Imbalance
{
   double   upper;
   double   lower;
   datetime time_start;
   datetime time_end;
   int      bar_index;
   bool     is_bullish;
   bool     active;
   string   obj_name;
};

struct AggressionData
{
   long     buy_volume;
   long     sell_volume;
   long     delta;
   datetime time;
   int      bar_index;
   string   obj_name;
};

//+------------------------------------------------------------------+
//| Buffers                                                           |
//+------------------------------------------------------------------+
double BufBOSBull[];
double BufBOSBear[];
double BufCHOCHBull[];
double BufCHOCHBear[];
double BufSwingHigh[];
double BufSwingLow[];

//+------------------------------------------------------------------+
//| Global variables                                                  |
//+------------------------------------------------------------------+
SwingPoint     g_swings[];
OrderBlock     g_obs[];
Imbalance      g_imbs[];
AggressionData g_agg[];
ENUM_TREND     g_trend = TREND_NONE;
int            g_last_sh_idx = -1;   // ultimo swing high index
int            g_last_sl_idx = -1;   // ultimo swing low index
double         g_last_sh_price = 0;
double         g_last_sl_price = 0;
string         g_prefix = "SMC_";
int            g_obj_counter = 0;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                          |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Verificar timeframe
   if(_Period != PERIOD_M5)
   {
      Print("AVISO: Este indicador foi projetado para M5. Timeframe atual: ", EnumToString(_Period));
   }

   //--- Buffers
   SetIndexBuffer(0, BufBOSBull, INDICATOR_DATA);
   SetIndexBuffer(1, BufBOSBear, INDICATOR_DATA);
   SetIndexBuffer(2, BufCHOCHBull, INDICATOR_DATA);
   SetIndexBuffer(3, BufCHOCHBear, INDICATOR_DATA);
   SetIndexBuffer(4, BufSwingHigh, INDICATOR_CALCULATIONS);
   SetIndexBuffer(5, BufSwingLow, INDICATOR_CALCULATIONS);

   //--- Arrow codes
   PlotIndexSetInteger(0, PLOT_ARROW, 233);   // seta para cima BOS
   PlotIndexSetInteger(1, PLOT_ARROW, 234);   // seta para baixo BOS
   PlotIndexSetInteger(2, PLOT_ARROW, 233);   // seta para cima CHOCH
   PlotIndexSetInteger(3, PLOT_ARROW, 234);   // seta para baixo CHOCH

   //--- Colors from inputs
   PlotIndexSetInteger(0, PLOT_LINE_COLOR, InpBOSBullColor);
   PlotIndexSetInteger(1, PLOT_LINE_COLOR, InpBOSBearColor);
   PlotIndexSetInteger(2, PLOT_LINE_COLOR, InpCHOCHBullColor);
   PlotIndexSetInteger(3, PLOT_LINE_COLOR, InpCHOCHBearColor);

   //--- Empty value
   PlotIndexSetDouble(0, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(1, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(2, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   PlotIndexSetDouble(3, PLOT_EMPTY_VALUE, EMPTY_VALUE);

   //--- Short name
   IndicatorSetString(INDICATOR_SHORTNAME, "SMC WDO (Imbalance+OB+BOS/CHOCH+T&T)");

   //--- Book
   if(InpShowAggression)
      MarketBookAdd(_Symbol);

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                         |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Remover todos os objetos criados
   ObjectsDeleteAll(0, g_prefix);

   if(InpShowAggression)
      MarketBookRelease(_Symbol);
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                               |
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
                const long &spread[])
{
   if(rates_total < InpSwingLen * 2 + 1)
      return(0);

   int start = prev_calculated > 0 ? prev_calculated - 1 : InpSwingLen;

   //--- Inicializar buffers na primeira execucao
   if(prev_calculated == 0)
   {
      ArrayInitialize(BufBOSBull, EMPTY_VALUE);
      ArrayInitialize(BufBOSBear, EMPTY_VALUE);
      ArrayInitialize(BufCHOCHBull, EMPTY_VALUE);
      ArrayInitialize(BufCHOCHBear, EMPTY_VALUE);
      ArrayInitialize(BufSwingHigh, EMPTY_VALUE);
      ArrayInitialize(BufSwingLow, EMPTY_VALUE);
   }

   //--- Processar cada barra
   for(int i = start; i < rates_total - 1; i++)
   {
      //--- 1. Detectar Swing Points
      DetectSwingPoints(i, high, low, time, rates_total);

      //--- 2. Detectar BOS / CHOCH (Order Blocks sao criados dentro desta funcao)
      if(InpShowBOS || InpShowCHOCH || InpShowOB)
         DetectStructureBreak(i, high, low, open, close, time, rates_total);

      //--- 3. Detectar Imbalance (FVG)
      if(InpShowImbalance)
         DetectImbalance(i, high, low, open, close, time, rates_total);
   }

   //--- 4. Agressao via Times & Trades (ultimos N candles)
   if(InpShowAggression && rates_total > 1)
   {
      int agg_start = MathMax(rates_total - InpAggPeriod, 1);
      for(int a = agg_start; a < rates_total; a++)
         ProcessAggression(a, time, open, high, low, close, volume, rates_total);
   }

   //--- 6. Checar mitigacao de Imbalance
   if(InpImbMitigated)
      CheckImbalanceMitigation(rates_total - 1, high, low);

   //--- 7. Checar mitigacao de Order Blocks
   CheckOBMitigation(rates_total - 1, high, low);

   //--- Limpar objetos antigos
   CleanOldObjects(rates_total, time);

   return(rates_total);
}

//+------------------------------------------------------------------+
//| Detectar Swing High e Swing Low                                   |
//+------------------------------------------------------------------+
void DetectSwingPoints(int idx, const double &high[], const double &low[],
                       const datetime &time[], int rates_total)
{
   if(idx < InpSwingLen || idx >= rates_total - InpSwingLen)
      return;

   //--- Swing High
   bool is_sh = true;
   for(int j = 1; j <= InpSwingLen; j++)
   {
      if(high[idx] <= high[idx - j] || high[idx] <= high[idx + j])
      {
         is_sh = false;
         break;
      }
   }

   if(is_sh)
   {
      BufSwingHigh[idx] = high[idx];

      SwingPoint sp;
      sp.price     = high[idx];
      sp.bar_index = idx;
      sp.time      = time[idx];
      sp.is_high   = true;
      sp.broken    = false;

      int size = ArraySize(g_swings);
      ArrayResize(g_swings, size + 1);
      g_swings[size] = sp;

      g_last_sh_price = high[idx];
      g_last_sh_idx   = idx;
   }

   //--- Swing Low
   bool is_sl = true;
   for(int j = 1; j <= InpSwingLen; j++)
   {
      if(low[idx] >= low[idx - j] || low[idx] >= low[idx + j])
      {
         is_sl = false;
         break;
      }
   }

   if(is_sl)
   {
      BufSwingLow[idx] = low[idx];

      SwingPoint sp;
      sp.price     = low[idx];
      sp.bar_index = idx;
      sp.time      = time[idx];
      sp.is_high   = false;
      sp.broken    = false;

      int size = ArraySize(g_swings);
      ArrayResize(g_swings, size + 1);
      g_swings[size] = sp;

      g_last_sl_price = low[idx];
      g_last_sl_idx   = idx;
   }
}

//+------------------------------------------------------------------+
//| Detectar BOS (Break of Structure) e CHOCH (Change of Character)  |
//+------------------------------------------------------------------+
void DetectStructureBreak(int idx, const double &high[], const double &low[],
                          const double &open[], const double &close[],
                          const datetime &time[], int rates_total)
{
   if(g_last_sh_idx < 0 || g_last_sl_idx < 0)
      return;

   //--- Verificar rompimento de Swing High (close acima do ultimo SH)
   if(close[idx] > g_last_sh_price && !IsSwingBroken(g_last_sh_idx, true))
   {
      MarkSwingBroken(g_last_sh_idx, true);

      if(g_trend == TREND_BULL || g_trend == TREND_NONE)
      {
         //--- BOS Bullish (continuacao de alta)
         if(InpShowBOS)
         {
            BufBOSBull[idx] = low[idx] - _Point * 50;
            DrawStructureLine(time[g_last_sh_idx], g_last_sh_price, time[idx], g_last_sh_price,
                              InpBOSBullColor, "BOS^", idx);
         }
         g_trend = TREND_BULL;

         if(InpAlertBOS)
            SendAlert("BOS Bullish detectado em " + _Symbol + " M5", idx, time);
      }
      else
      {
         //--- CHOCH Bullish (mudanca de bearish para bullish)
         if(InpShowCHOCH)
         {
            BufCHOCHBull[idx] = low[idx] - _Point * 50;
            DrawStructureLine(time[g_last_sh_idx], g_last_sh_price, time[idx], g_last_sh_price,
                              InpCHOCHBullColor, "CHOCH^", idx);
         }
         g_trend = TREND_BULL;

         if(InpAlertCHOCH)
            SendAlert("CHOCH Bullish detectado em " + _Symbol + " M5! Possivel reversao!", idx, time);
      }

      //--- Criar Order Block no ultimo candle contrario (bearish) antes do rompimento
      if(InpShowOB)
         FindOrderBlock(idx, high, low, open, close, time, true, rates_total);
   }

   //--- Verificar rompimento de Swing Low (close abaixo do ultimo SL)
   if(close[idx] < g_last_sl_price && !IsSwingBroken(g_last_sl_idx, false))
   {
      MarkSwingBroken(g_last_sl_idx, false);

      if(g_trend == TREND_BEAR || g_trend == TREND_NONE)
      {
         //--- BOS Bearish (continuacao de baixa)
         if(InpShowBOS)
         {
            BufBOSBear[idx] = high[idx] + _Point * 50;
            DrawStructureLine(time[g_last_sl_idx], g_last_sl_price, time[idx], g_last_sl_price,
                              InpBOSBearColor, "BOSv", idx);
         }
         g_trend = TREND_BEAR;

         if(InpAlertBOS)
            SendAlert("BOS Bearish detectado em " + _Symbol + " M5", idx, time);
      }
      else
      {
         //--- CHOCH Bearish (mudanca de bullish para bearish)
         if(InpShowCHOCH)
         {
            BufCHOCHBear[idx] = high[idx] + _Point * 50;
            DrawStructureLine(time[g_last_sl_idx], g_last_sl_price, time[idx], g_last_sl_price,
                              InpCHOCHBearColor, "CHOCHv", idx);
         }
         g_trend = TREND_BEAR;

         if(InpAlertCHOCH)
            SendAlert("CHOCH Bearish detectado em " + _Symbol + " M5! Possivel reversao!", idx, time);
      }

      //--- Criar Order Block no ultimo candle contrario (bullish) antes do rompimento
      if(InpShowOB)
         FindOrderBlock(idx, high, low, open, close, time, false, rates_total);
   }
}

//+------------------------------------------------------------------+
//| Verificar se swing point ja foi rompido                           |
//+------------------------------------------------------------------+
bool IsSwingBroken(int swing_idx, bool is_high)
{
   for(int i = ArraySize(g_swings) - 1; i >= 0; i--)
   {
      if(g_swings[i].bar_index == swing_idx && g_swings[i].is_high == is_high)
         return g_swings[i].broken;
   }
   return false;
}

//+------------------------------------------------------------------+
//| Marcar swing point como rompido                                   |
//+------------------------------------------------------------------+
void MarkSwingBroken(int swing_idx, bool is_high)
{
   for(int i = ArraySize(g_swings) - 1; i >= 0; i--)
   {
      if(g_swings[i].bar_index == swing_idx && g_swings[i].is_high == is_high)
      {
         g_swings[i].broken = true;
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Desenhar linha de estrutura (BOS / CHOCH)                         |
//+------------------------------------------------------------------+
void DrawStructureLine(datetime t1, double p1, datetime t2, double p2,
                       color clr, string label, int idx)
{
   string name = g_prefix + "SL_" + IntegerToString(g_obj_counter++);

   if(ObjectCreate(0, name, OBJ_TREND, 0, t1, p1, t2, p2))
   {
      ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DASH);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, name, OBJPROP_RAY_RIGHT, false);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }

   //--- Label
   string lbl_name = g_prefix + "LBL_" + IntegerToString(g_obj_counter++);
   datetime mid_t = t1 + (t2 - t1) / 2;
   double offset = (StringFind(label, "^") >= 0) ? _Point * 30 : -_Point * 30;

   if(ObjectCreate(0, lbl_name, OBJ_TEXT, 0, mid_t, p1 + offset))
   {
      ObjectSetString(0, lbl_name, OBJPROP_TEXT, label);
      ObjectSetInteger(0, lbl_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, lbl_name, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, lbl_name, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lbl_name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Detectar Imbalance / Fair Value Gap                               |
//+------------------------------------------------------------------+
void DetectImbalance(int idx, const double &high[], const double &low[],
                     const double &open[], const double &close[],
                     const datetime &time[], int rates_total)
{
   if(idx < 2 || idx >= rates_total - 1)
      return;

   //--- Imbalance Bullish: high[idx-2] < low[idx] (gap entre candle -2 e candle atual)
   if(high[idx - 2] < low[idx])
   {
      Imbalance imb;
      imb.upper      = low[idx];
      imb.lower      = high[idx - 2];
      imb.time_start = time[idx - 2];
      imb.time_end   = time[idx];
      imb.bar_index  = idx - 1;   // o candle do meio
      imb.is_bullish = true;
      imb.active     = true;
      imb.obj_name   = g_prefix + "IMB_" + IntegerToString(g_obj_counter++);

      DrawImbalanceRect(imb, time, rates_total);

      int size = ArraySize(g_imbs);
      ArrayResize(g_imbs, size + 1);
      g_imbs[size] = imb;
   }

   //--- Imbalance Bearish: low[idx-2] > high[idx] (gap entre candle -2 e candle atual)
   if(low[idx - 2] > high[idx])
   {
      Imbalance imb;
      imb.upper      = low[idx - 2];
      imb.lower      = high[idx];
      imb.time_start = time[idx - 2];
      imb.time_end   = time[idx];
      imb.bar_index  = idx - 1;
      imb.is_bullish = false;
      imb.active     = true;
      imb.obj_name   = g_prefix + "IMB_" + IntegerToString(g_obj_counter++);

      DrawImbalanceRect(imb, time, rates_total);

      int size = ArraySize(g_imbs);
      ArrayResize(g_imbs, size + 1);
      g_imbs[size] = imb;
   }
}

//+------------------------------------------------------------------+
//| Desenhar retangulo de Imbalance                                   |
//+------------------------------------------------------------------+
void DrawImbalanceRect(Imbalance &imb, const datetime &time[], int rates_total)
{
   datetime t_end = (imb.bar_index + InpImbMaxBars < rates_total)
                    ? time[imb.bar_index + InpImbMaxBars]
                    : time[rates_total - 1] + PeriodSeconds() * 10;

   if(ObjectCreate(0, imb.obj_name, OBJ_RECTANGLE, 0,
                   imb.time_start, imb.upper, t_end, imb.lower))
   {
      color clr = imb.is_bullish ? InpImbBullColor : InpImbBearColor;
      ObjectSetInteger(0, imb.obj_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, imb.obj_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, imb.obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, imb.obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, imb.obj_name, OBJPROP_TOOLTIP,
                      (imb.is_bullish ? "FVG Bull" : "FVG Bear") +
                      "\nSuperior: " + DoubleToString(imb.upper, _Digits) +
                      "\nInferior: " + DoubleToString(imb.lower, _Digits));
   }

   //--- Label FVG
   string lbl = g_prefix + "IMBLBL_" + IntegerToString(g_obj_counter++);
   if(ObjectCreate(0, lbl, OBJ_TEXT, 0, imb.time_start, (imb.upper + imb.lower) / 2.0))
   {
      ObjectSetString(0, lbl, OBJPROP_TEXT, imb.is_bullish ? "FVG^" : "FVGv");
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, imb.is_bullish ? InpImbBullColor : InpImbBearColor);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 7);
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Checar mitigacao de Imbalance                                     |
//+------------------------------------------------------------------+
void CheckImbalanceMitigation(int idx, const double &high[], const double &low[])
{
   for(int i = ArraySize(g_imbs) - 1; i >= 0; i--)
   {
      if(!g_imbs[i].active)
         continue;

      bool mitigated = false;

      if(g_imbs[i].is_bullish)
      {
         //--- Mitigado quando preco volta e fecha abaixo do nivel inferior
         if(low[idx] <= g_imbs[i].lower)
            mitigated = true;
      }
      else
      {
         //--- Mitigado quando preco volta e fecha acima do nivel superior
         if(high[idx] >= g_imbs[i].upper)
            mitigated = true;
      }

      if(mitigated)
      {
         g_imbs[i].active = false;
         ObjectDelete(0, g_imbs[i].obj_name);
      }
   }
}

//+------------------------------------------------------------------+
//| Encontrar Order Block (ultimo candle contrario antes do BOS)     |
//+------------------------------------------------------------------+
void FindOrderBlock(int bos_idx, const double &high[], const double &low[],
                    const double &open[], const double &close[],
                    const datetime &time[], bool is_bullish_bos, int rates_total)
{
   //--- Procurar o ultimo candle contrario antes do rompimento
   for(int i = bos_idx - 1; i >= MathMax(0, bos_idx - 20); i--)
   {
      bool is_bearish_candle = (close[i] < open[i]);
      bool is_bullish_candle = (close[i] > open[i]);

      if(is_bullish_bos && is_bearish_candle)
      {
         //--- Order Block Bullish = ultimo candle bearish antes do BOS bullish
         CreateOrderBlock(i, high, low, open, close, time, true, rates_total);
         return;
      }
      else if(!is_bullish_bos && is_bullish_candle)
      {
         //--- Order Block Bearish = ultimo candle bullish antes do BOS bearish
         CreateOrderBlock(i, high, low, open, close, time, false, rates_total);
         return;
      }
   }
}

//+------------------------------------------------------------------+
//| Criar Order Block                                                 |
//+------------------------------------------------------------------+
void CreateOrderBlock(int idx, const double &high[], const double &low[],
                      const double &open[], const double &close[],
                      const datetime &time[], bool is_bullish, int rates_total)
{
   OrderBlock ob;
   ob.high       = high[idx];
   ob.low        = low[idx];
   ob.open       = open[idx];
   ob.close      = close[idx];
   ob.time_start = time[idx];
   ob.bar_index  = idx;
   ob.is_bullish = is_bullish;
   ob.active     = true;
   ob.obj_name   = g_prefix + "OB_" + IntegerToString(g_obj_counter++);

   //--- Extensao do retangulo
   datetime t_end = (idx + InpOBMaxBars < rates_total)
                    ? time[idx + InpOBMaxBars]
                    : time[rates_total - 1] + PeriodSeconds() * 20;
   ob.time_end = t_end;

   //--- Desenhar retangulo
   if(ObjectCreate(0, ob.obj_name, OBJ_RECTANGLE, 0,
                   ob.time_start, ob.high, t_end, ob.low))
   {
      color clr = is_bullish ? InpOBBullColor : InpOBBearColor;
      ObjectSetInteger(0, ob.obj_name, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, ob.obj_name, OBJPROP_FILL, true);
      ObjectSetInteger(0, ob.obj_name, OBJPROP_BACK, true);
      ObjectSetInteger(0, ob.obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, ob.obj_name, OBJPROP_TOOLTIP,
                      (is_bullish ? "OB Bull" : "OB Bear") +
                      "\nHigh: " + DoubleToString(ob.high, _Digits) +
                      "\nLow: " + DoubleToString(ob.low, _Digits));
   }

   //--- Label OB
   string lbl = g_prefix + "OBLBL_" + IntegerToString(g_obj_counter++);
   if(ObjectCreate(0, lbl, OBJ_TEXT, 0, ob.time_start, (ob.high + ob.low) / 2.0))
   {
      ObjectSetString(0, lbl, OBJPROP_TEXT, is_bullish ? "OB^" : "OBv");
      ObjectSetInteger(0, lbl, OBJPROP_COLOR, is_bullish ? InpOBBullColor : InpOBBearColor);
      ObjectSetInteger(0, lbl, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, lbl, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, lbl, OBJPROP_SELECTABLE, false);
   }

   int size = ArraySize(g_obs);
   ArrayResize(g_obs, size + 1);
   g_obs[size] = ob;

   if(InpAlertOB)
   {
      string msg = (is_bullish ? "Order Block BULLISH" : "Order Block BEARISH") +
                   " detectado em " + _Symbol + " M5" +
                   " | High: " + DoubleToString(ob.high, _Digits) +
                   " | Low: " + DoubleToString(ob.low, _Digits);
      Alert(msg);
      if(InpAlertPush)
         SendNotification(msg);
   }
}

//+------------------------------------------------------------------+
//| Checar mitigacao de Order Block                                   |
//+------------------------------------------------------------------+
void CheckOBMitigation(int idx, const double &high[], const double &low[])
{
   for(int i = ArraySize(g_obs) - 1; i >= 0; i--)
   {
      if(!g_obs[i].active)
         continue;

      bool mitigated = false;

      if(g_obs[i].is_bullish)
      {
         //--- OB bullish mitigado quando preco toca a zona e sobe (preco atingiu low do OB)
         if(low[idx] <= g_obs[i].low)
            mitigated = true;
      }
      else
      {
         //--- OB bearish mitigado quando preco toca a zona e desce (preco atingiu high do OB)
         if(high[idx] >= g_obs[i].high)
            mitigated = true;
      }

      if(mitigated)
      {
         g_obs[i].active = false;
         //--- Alterar estilo visual para indicar mitigacao
         ObjectSetInteger(0, g_obs[i].obj_name, OBJPROP_STYLE, STYLE_DOT);
         color mitClr = g_obs[i].is_bullish ? C'80,80,80' : C'80,80,80';
         ObjectSetInteger(0, g_obs[i].obj_name, OBJPROP_COLOR, mitClr);
      }
   }
}

//+------------------------------------------------------------------+
//| Processar Agressao via Times & Trades (Tick Data)                |
//+------------------------------------------------------------------+
void ProcessAggression(int idx, const datetime &time[], const double &open[],
                       const double &high[], const double &low[],
                       const double &close[], const long &volume[], int rates_total)
{
   if(idx < 1)
      return;

   //--- Obter ticks do candle atual
   MqlTick ticks[];
   datetime from_time = time[idx];
   datetime to_time   = from_time + PeriodSeconds();

   int copied = CopyTicksRange(_Symbol, ticks, COPY_TICKS_TRADE, 
                                (ulong)from_time * 1000, (ulong)to_time * 1000);

   if(copied <= 0)
      return;

   long buy_vol  = 0;
   long sell_vol = 0;

   for(int t = 0; t < copied; t++)
   {
      //--- Classificar por flags de tick
      if((ticks[t].flags & TICK_FLAG_BUY) != 0)
         buy_vol += (long)ticks[t].volume;
      else if((ticks[t].flags & TICK_FLAG_SELL) != 0)
         sell_vol += (long)ticks[t].volume;
      else
      {
         //--- Fallback: classificar pelo ultimo preco vs bid/ask
         if(ticks[t].last >= ticks[t].ask)
            buy_vol += (long)ticks[t].volume;
         else if(ticks[t].last <= ticks[t].bid)
            sell_vol += (long)ticks[t].volume;
         else
         {
            //--- Se preco esta entre bid e ask, dividir proporcionalmente
            if(ticks[t].ask > ticks[t].bid)
            {
               double ratio = (ticks[t].last - ticks[t].bid) / (ticks[t].ask - ticks[t].bid);
               buy_vol  += (long)MathRound(ticks[t].volume * ratio);
               sell_vol += (long)MathRound(ticks[t].volume * (1.0 - ratio));
            }
         }
      }
   }

   long delta = buy_vol - sell_vol;

   //--- So mostrar se delta supera o limiar
   if(MathAbs(delta) < InpDeltaThreshold)
      return;

   //--- Criar label de agressao no grafico
   string agg_name = g_prefix + "AGG_" + IntegerToString(idx);

   //--- Remover label anterior do mesmo candle se existir
   ObjectDelete(0, agg_name);

   double y_pos;
   color  agg_clr;
   string agg_text;

   if(delta > 0)
   {
      //--- Agressao compradora
      y_pos    = low[idx] - _Point * 80;
      agg_clr  = InpAggBuyColor;
      agg_text = "A+" + IntegerToString(buy_vol) +
                 "\nP-" + IntegerToString(sell_vol) +
                 "\nD+" + IntegerToString(delta);
   }
   else
   {
      //--- Agressao vendedora
      y_pos    = high[idx] + _Point * 80;
      agg_clr  = InpAggSellColor;
      agg_text = "A-" + IntegerToString(sell_vol) +
                 "\nP+" + IntegerToString(buy_vol) +
                 "\nD" + IntegerToString(delta);
   }

   if(ObjectCreate(0, agg_name, OBJ_TEXT, 0, time[idx], y_pos))
   {
      ObjectSetString(0, agg_name, OBJPROP_TEXT, agg_text);
      ObjectSetInteger(0, agg_name, OBJPROP_COLOR, agg_clr);
      ObjectSetInteger(0, agg_name, OBJPROP_FONTSIZE, InpAggFontSize);
      ObjectSetString(0, agg_name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, agg_name, OBJPROP_ANCHOR, delta > 0 ? ANCHOR_UPPER : ANCHOR_LOWER);
      ObjectSetInteger(0, agg_name, OBJPROP_SELECTABLE, false);
      ObjectSetString(0, agg_name, OBJPROP_TOOLTIP,
                      "Agressao Compradora: " + IntegerToString(buy_vol) +
                      "\nAgressao Vendedora: " + IntegerToString(sell_vol) +
                      "\nDelta: " + IntegerToString(delta) +
                      "\nTotal Ticks: " + IntegerToString(copied));
   }
}

//+------------------------------------------------------------------+
//| Callback do Book (DOM)                                            |
//+------------------------------------------------------------------+
void OnBookEvent(const string &symbol)
{
   if(symbol != _Symbol || !InpShowAggression)
      return;

   MqlBookInfo book[];
   if(!MarketBookGet(_Symbol, book))
      return;

   long bid_depth = 0;
   long ask_depth = 0;

   for(int i = 0; i < ArraySize(book); i++)
   {
      if(book[i].type == BOOK_TYPE_SELL || book[i].type == BOOK_TYPE_SELL_MARKET)
         ask_depth += book[i].volume;
      else if(book[i].type == BOOK_TYPE_BUY || book[i].type == BOOK_TYPE_BUY_MARKET)
         bid_depth += book[i].volume;
   }

   //--- Atualizar label de profundidade do DOM
   string dom_name = g_prefix + "DOM_DEPTH";
   ObjectDelete(0, dom_name);

   string dom_text = "DOM | Bid:" + IntegerToString(bid_depth) +
                     " | Ask:" + IntegerToString(ask_depth);

   if(ObjectCreate(0, dom_name, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetString(0, dom_name, OBJPROP_TEXT, dom_text);
      ObjectSetInteger(0, dom_name, OBJPROP_CORNER, CORNER_RIGHT_UPPER);
      ObjectSetInteger(0, dom_name, OBJPROP_XDISTANCE, 10);
      ObjectSetInteger(0, dom_name, OBJPROP_YDISTANCE, 30);
      ObjectSetInteger(0, dom_name, OBJPROP_COLOR,
                       bid_depth > ask_depth ? InpAggBuyColor : InpAggSellColor);
      ObjectSetInteger(0, dom_name, OBJPROP_FONTSIZE, 10);
      ObjectSetString(0, dom_name, OBJPROP_FONT, "Consolas");
      ObjectSetInteger(0, dom_name, OBJPROP_SELECTABLE, false);
   }
}

//+------------------------------------------------------------------+
//| Enviar alerta                                                     |
//+------------------------------------------------------------------+
void SendAlert(string msg, int idx, const datetime &time[])
{
   static datetime last_alert_time = 0;

   //--- Evitar alertas repetidos no mesmo candle
   if(time[idx] == last_alert_time)
      return;

   last_alert_time = time[idx];
   Alert(msg);

   if(InpAlertPush)
      SendNotification(msg);
}

//+------------------------------------------------------------------+
//| Limpar objetos antigos fora da janela visivel                     |
//+------------------------------------------------------------------+
void CleanOldObjects(int rates_total, const datetime &time[])
{
   int max_bars = MathMax(InpImbMaxBars, InpOBMaxBars) + 50;
   if(rates_total < max_bars)
      return;

   datetime cutoff = time[rates_total - max_bars * 2];

   //--- Limpar imbalances antigos inativos
   for(int i = ArraySize(g_imbs) - 1; i >= 0; i--)
   {
      if(!g_imbs[i].active && g_imbs[i].time_start < cutoff)
      {
         ObjectDelete(0, g_imbs[i].obj_name);
         ArrayRemove(g_imbs, i, 1);
      }
   }

   //--- Limpar OBs antigos inativos
   for(int i = ArraySize(g_obs) - 1; i >= 0; i--)
   {
      if(!g_obs[i].active && g_obs[i].time_start < cutoff)
      {
         ObjectDelete(0, g_obs[i].obj_name);
         ArrayRemove(g_obs, i, 1);
      }
   }

   //--- Limpar swing points antigos
   for(int i = ArraySize(g_swings) - 1; i >= 0; i--)
   {
      if(g_swings[i].broken && g_swings[i].time < cutoff)
         ArrayRemove(g_swings, i, 1);
   }
}
//+------------------------------------------------------------------+
