#include <Trade\PositionInfo.mqh>   //  подключаем модуль для получения информации о наших позициях
#include <Trade\Trade.mqh>          //  подключаем модуль для Торговли
#include <Trade\SymbolInfo.mqh>     //  подключаем модуль для получения информации о валютной паре
#include <Indicators\TimeSeries.mqh>

CPositionInfo     a_pos;
CTrade            a_trade;
CSymbolInfo       a_symbol;
CiClose           Close;
//+------------------------------------------------------------------+
//|                                                       Martin.mq5 |
//|                                                       © Martynov |
//|                               https://github.com/vikneo/MQL5.git |
//+------------------------------------------------------------------+
#property copyright "© Martynov"
#property link      "https://github.com/vikneo/MQL5.git"
#property version   "1.00"
#property description "Сеточный советникпостроен на работе Мантин Гейла,"
#property description "работает по сигналам индикаторов:"
#property description "- Stochastic;"
#property description "- Envelopes;"
#property description "Гибкая настройки индикаторов."

input string         MM            = "= Money Management =";
input double         Lots          = 0.01;
input double         addToLot      = 2; //addToLot - добавление к открытому лоту
input ushort         Step          = 95;
input double         Profit        = 100;
//+------------------------------------------------------------------+
input string         Stoch         = "= Параметры индикатора Stochastic =";
input int            InpKPeriod    = 45; // K Period
input int            InpDPeriod    = 16; // D Period
input int            InpSlowing    = 10; // Slowing
input ENUM_MA_METHOD MaMethod      = MODE_SMA;
input ENUM_STO_PRICE PriceField    = STO_LOWHIGH;
input double         BuyLevel      = 12;
input double         SellLevel     = 90;
//+------------------------------------------------------------------+
input string             Envelopes     = "= Параметры индикатора Envelopes =";
input int                ATRPeriod     = 20;
input ENUM_MA_METHOD     ATRMethod     = MODE_SMA;
input int                ATRShift      = 0;
input double             ATRDeviation  = 0.300;
//+------------------------------------------------------------------+
input ulong          Magic         = 12345;
input ulong          Slippage      = 10;

double eStep      = 0;
double last_price = 0;
double last_lots  = 0;
double points;
int    hStoch, tma, fractals, env_1, env_2;
int    last_pos_type = -1;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(!a_symbol.Name(Symbol()))
     {
         return(INIT_FAILED);
     }
   RefreshRates();

   a_trade.SetExpertMagicNumber(Magic);
   a_trade.SetMarginMode();
   a_trade.SetTypeFillingBySymbol(a_symbol.Name());
   a_trade.SetDeviationInPoints(Slippage);

   int digits = 1;
   if (a_symbol.Digits() == 3 || a_symbol.Digits() == 5)
   {
      digits = 10;
   }

   points = a_symbol.Point() * digits;
   eStep  = Step * points;

   env_1      = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, ATRPeriod, ATRShift, ATRMethod, PRICE_HIGH, ATRDeviation);
   env_2     = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, ATRPeriod, ATRShift, ATRMethod, PRICE_LOW, ATRDeviation);
   hStoch   = iStochastic(a_symbol.Name(), PERIOD_CURRENT, InpKPeriod, InpDPeriod, InpSlowing, MaMethod, PriceField);

   if (tma == INVALID_HANDLE)
   {
      Print("Не удалось создать описатель индикатора 'Envelopes'");
      return(INIT_FAILED);
   }
   if (hStoch == INVALID_HANDLE)
   {
      Print("Не удалось создать описатель индикатора 'Stochastic'");
      return(INIT_FAILED);
   }
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!RefreshRates())
      return;

   string s;

   if (CalcProfit(POSITION_TYPE_BUY) >= Profit)
      CloseAll(POSITION_TYPE_BUY);
   if (CalcProfit(POSITION_TYPE_SELL) >= Profit)
      CloseAll(POSITION_TYPE_SELL);

   double tma_avg = GetBufferIndicator(tma, UPPER_LINE, 1);
   env_up  = GetBufferIndicator(tma, UPPER_LINE, 1);
   env_low = GetBufferIndicator(tma, LOWER_LINE, 1);

   s += "\n\nTMA UP  - " + DoubleToString(env_up, _Digits);
   s += "\nTMA AVG -" + DoubleToString(tma_avg, _Digits);
   s += "\nTMA LOW -" + DoubleToString(env_low, _Digits);
   s += "\nPRICE - " + DoubleToString(a_symbol.Ask(), _Digits);

   if (a_symbol.Ask() < env_up && a_symbol.Ask() > env_low) Comment("");
   if (a_symbol.Bid() > env_up) s += "\nSIGNAL TMA - ↓";
   if (a_symbol.Ask() < env_low) s += "\nSIGNAL TMA - ↑";

   int count = PosCount();
   if (count < 1)
   {
      double mLine = GetBufferIndicator(hStoch,MAIN_LINE, 1);
      double sLine = GetBufferIndicator(hStoch, SIGNAL_LINE, 1);

      if (a_symbol.Ask() < env_low && sLine <= BuyLevel) // && mLine > sLine && sLine < BuyLevel Проверка между основной линией и сигнальной
      {
         OpenBuy(Lots);
         return;
      }

      if (a_symbol.Bid() > env_up && sLine >= SellLevel) // && mLine < sLine && sLine > SellLevel Проверка между основной линией и сигнальной
      {
         OpenSell(Lots);
         return;
      }

     Comment(s);
   }

   if (last_price != 0 && last_pos_type >= 0 && last_lots != 0)
   {
      if (last_pos_type == POSITION_TYPE_BUY)
      {
         if (a_symbol.Ask() <= last_price - eStep)
         {
            double next_lots = CalcLots(last_lots * addToLot);

            if (next_lots != 0)
            {
               OpenBuy(next_lots);
               return;
            }
         }
      }
   }

   if (last_price != 0 && last_pos_type >= 0 && last_lots != 0)
   {
      if (last_pos_type == POSITION_TYPE_SELL)
      {
         if (a_symbol.Bid() >= last_price + eStep)
         {
            double next_lots = CalcLots(last_lots * addToLot);

            if (next_lots != 0)
            {
               OpenSell(next_lots);
               return;
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
bool OpenBuy(double _lots)
{
   if (_lots == 0)
   {
      Print("Ошибка объема для открытия позиции на покупку!");
      return(false);
   }

   if (a_trade.Buy(_lots, a_symbol.Name(), a_symbol.Ask(), 0, 0))
   {
      if (a_trade.ResultDeal() == 0)
      {
         Print("Ошибка открытия позиции на покупку!");
         return(false);
      }
   }

   return(true);
}
//+------------------------------------------------------------------+
bool OpenSell(double _lots)
{
   if (_lots == 0)
   {
      Print("Ошибка объема для открытия позиции на продажу!");
      return(false);
   }

   if (a_trade.Sell(_lots, a_symbol.Name(), a_symbol.Bid(), 0, 0))
   {
      if (a_trade.ResultDeal() == 0)
      {
         Print("Ошибка открытия позиции на продажу!");
         return(false);
      }
   }

   return(true);
}
//+------------------------------------------------------------------+
double CalcProfit(ENUM_POSITION_TYPE pos_type)
{
   double profit = 0;

   for (int i = PositionsTotal() -1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.PositionType() == pos_type && a_pos.Magic() == Magic && a_pos.Symbol() == a_symbol.Name())
         {
            profit += a_pos.Profit();
         }
      }
   }

   return(profit);
}
//+------------------------------------------------------------------+
void CloseAll(ENUM_POSITION_TYPE pos_type)
{
   for (int i = PositionsTotal() -1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.PositionType() == pos_type && a_pos.Magic() == Magic && a_pos.Symbol() == a_symbol.Name())
         {
            a_trade.PositionClose(a_pos.Ticket());
         }
      }
   }
}
//+------------------------------------------------------------------+
double CalcLots(double lots)
{
   double new_lots = NormalizeDouble(lots, 2);
   double step_lots = a_symbol.LotsStep();

   if (step_lots > 0)
      new_lots = step_lots * MathFloor(new_lots / step_lots);

   double minlot = a_symbol.LotsMin();

   if (new_lots < minlot)
      new_lots = minlot;

   double maxlot = a_symbol.LotsMax();

   if (new_lots > maxlot)
      new_lots = maxlot;

   return(new_lots);
}
//+------------------------------------------------------------------+
double GetBufferIndicator(const int handle, const int buffer, const int index)
{
   // Копируем данные индикатора
   double buffInd[3];
   ResetLastError();

   if (CopyBuffer(handle, buffer, index, 3, buffInd) < 0)
   {
      Print("Ошибка получения данных с индикатора!");
      return(0);
   }
   return(buffInd[0]);
}
//+------------------------------------------------------------------+
int PosCount()
{
   // Подсчет количества открытых позиций
   int count = 0;
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.Symbol() == a_symbol.Name() && a_pos.Magic() == Magic)
            count++;
      }
   }
   return(count);
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
bool RefreshRates()
{
   if (!a_symbol.RefreshRates())
   {
      Print("Не удалось обновить катировки!");
      return(false);
   }

   if (a_symbol.Ask() == 0 || a_symbol.Bid() == 0)
   {
      return(false);
   }

   return(true);
}
//+------------------------------------------------------------------+
//| TradeTransaction function                                        |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result)
{
   if (trans.type == TRADE_TRANSACTION_DEAL_ADD) // Проверка если появилась позиция в рынке
   {
      long deal_type = -1;
      long deal_entry = -1;
      long deal_magic = 0;

      double deal_volume = 0;
      double deal_price = 0;
      string deal_symbol = "";

      if (HistoryDealSelect(trans.deal))
      {
         deal_type   = HistoryDealGetInteger(trans.deal, DEAL_TYPE);
         deal_entry  = HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
         deal_magic  = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);

         deal_volume = HistoryDealGetDouble(trans.deal, DEAL_VOLUME);
         deal_price  = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
         deal_symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
      }
      else return;

      if (deal_symbol == a_symbol.Name() && deal_magic == Magic)
      {
         if (deal_entry == DEAL_ENTRY_IN && (deal_type == DEAL_TYPE_BUY || deal_type == DEAL_TYPE_SELL))
         {
            last_price = deal_price;
            last_pos_type = (deal_type == DEAL_TYPE_BUY) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
            last_lots = deal_volume;
         }
         else if (deal_entry == DEAL_ENTRY_OUT)
         {
            last_lots = 0;
            last_pos_type = -1;
            last_price = 0;
         }
      }
   }
}
//+------------------------------------------------------------------+
