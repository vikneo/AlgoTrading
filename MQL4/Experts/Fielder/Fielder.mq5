#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>
#include <JAson.mqh>

CPositionInfo  a_pos;
CTrade         a_trade;
CSymbolInfo    a_symbol;
COrderInfo     a_order;
CJAVal JsonValue;

//+------------------------------------------------------------------+
//|                                                      Fielder.mq5 |
//|                                                         Martynov |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Martynov"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description    "Советник работает по методу Мартин Гейла";
#property description    "Profit:";
#property description    "- рублевый счет = 250";
#property description    "- долларовый счет = 3";

//+------------------------------------------------------------------+
//| Inputs Variable                                                  |
//+------------------------------------------------------------------+
input string  Name          = " --= Maxan =-- "; // Название советника
input bool    UseMM         = true;  // Управление Maney Management
input bool    Traling       = false; // Включение ТрелингСтоп
input int     TralingStep   = 1;     // TralingStep - шаг тралла
input int     MaxTrades     = 1;     // Количество ордеров для сделок
input double  RiskLots      = 2;     // Нагрузка на дипозит в %
input int     RiskStop      = 110;   // Stoploss для расчета лота
input double  Lots          = 0.01;  // Размер лота
input double  MaxLots       = 10;    // Максимальный размера лота
input string  _             = "--= Martingale =-- ";    // Настройки для Мартингейла
input bool    Martingale    = true;  // Отключение Мартингейла
input int     Step          = 400;   // Шаг открытия след ордера
input int     Profit        = 250;   // Profit для закрытия сделки
input double  Multiplier    = 2;     // Множитель для след лота
input string  __            = " --= Expert =-- ";    // Настройки советника
input int     TryCount      = 10;    // Количество попыток для открытия ордера
input int     Magic         = 1234;  // Магический номер советника
input int     Slippage      = 10;    // Проскальзивание
input bool    ExpertStop    = false; // Ручное отклюсение советника
//+------------------------------------------------------------------+
input string  ___                     = " --= RSI =-- ";   // Настройки индикатора
input int                MaPeriod     = 9;
input ENUM_APPLIED_PRICE AppledPrice  = PRICE_MEDIAN;
input int buy_level                   = 20;
input int sell_level                  = 87;
//+------------------------------------------------------------------+
input string  ____         = " --= Envelopes =-- ";    // Настройки индикатора
input double  Deviation    = 0.06;
//+------------------------------------------------------------------+
int aRSI, aBuls, aBears, env_up, env_low;
int Stoploss      = RiskStop;
int last_pos_type = -1;

double o_lots, o_sl, o_price, profit, points, next_profit;
double eStep      = 0;
double last_price = 0;
double last_lots  = 0;

ulong levelBuls   = 240;
ulong levelBears  = 240;

bool   FlagOrder  = false;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if (!a_symbol.Name(Symbol())) return(INIT_FAILED);

   points = a_symbol.Point();
   eStep  = Step * points;

   RefreshRates();

   a_trade.SetExpertMagicNumber(Magic);
   a_trade.SetMarginMode();
   a_trade.SetTypeFillingBySymbol(a_symbol.Name());
   a_trade.SetDeviationInPoints(Slippage);

   env_up = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, 14, 0, MODE_LWMA, MODE_HIGH, Deviation);
   env_low = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, 14, 0, MODE_LWMA, MODE_LOW, Deviation);

   aRSI = iRSI(a_symbol.Name(),PERIOD_CURRENT, MaPeriod, AppledPrice);

   aBuls  = iBullsPower(a_symbol.Name(), PERIOD_CURRENT, 13);
   aBears = iBearsPower(a_symbol.Name(), PERIOD_CURRENT, 13);

   if (env_up == INVALID_HANDLE || env_low == INVALID_HANDLE)
   {
      Print("Не удалось получить описатель индикатора Envelopes.\nОписание ошибки: " + IntegerToString(GetLastError()));
      return(INIT_FAILED);
   }
   if(aRSI == INVALID_HANDLE)
   {
      Print("Не удалось получить описатель индикатора Stochastic.\nОписание ошибки: " + IntegerToString(GetLastError()));
      return(INIT_FAILED);
   }

   int digits = 1;
   if (a_symbol.Digits() == 3 || a_symbol.Digits() == 5) digits = 10;

   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (Martingale)
   {
      if (CalcProfit(POSITION_TYPE_BUY) >= next_profit)
         CloseAll(POSITION_TYPE_BUY);
      if (CalcProfit(POSITION_TYPE_SELL) >= next_profit)
         CloseAll(POSITION_TYPE_SELL);
   }

   if (Traling) TrailingStop();

   profit = BalansProfit();

   if (!RefreshRates()) return;

   if (UseMM)
   {
      o_lots = NormalizeDouble(LotsBuyRisk(CountTrades(), RiskLots, Stoploss), 2);
      if (o_lots >= MaxLots) o_lots = MaxLots;

      next_profit = Profit;
      if (o_lots > 0.1)
      {
         //next_profit += (o_lots * 10) * (Profit * Profit);
         next_profit += profit * 0.01;
         Print(next_profit);
      }
   }
   else o_lots = Lots;

   double BulsPoint  = NormalizeDouble(levelBuls * a_symbol.Point(), _Digits);
   double BearsPoint = NormalizeDouble(-1  * (levelBears * a_symbol.Point()), _Digits);

   double env_up_befor = GetBufferIndicator(env_up, UPPER_LINE, 0, 1) + (18 * _Point);
   double env_low_befor = GetBufferIndicator(env_low, LOWER_LINE, 0, 1) - (18 * _Point);

   double rsi_curr = GetBufferIndicator(aRSI, MAIN_LINE, 0, 1);
   double rsi_preview = GetBufferIndicator(aRSI, MAIN_LINE, 1, 1);

   double buls_befor = GetBufferIndicator(aBuls, 0, 1, 1);
   double bears_befor = GetBufferIndicator(aBears, 0, 1, 1);

   double spread = a_symbol.Spread();
   string s = "";

   s += "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
   s += "\nLOT            :   " + DoubleToString(o_lots, 2);
   s += "\nBalans         :   " + DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE), 2);
   s += "\nEquity         :   " + DoubleToString(AccountInfoDouble(ACCOUNT_EQUITY), 2);
   s += "\nProfit           :   " + DoubleToString(profit, 2);
   s += "\nClosePos      :   " + DoubleToString(next_profit, 2);
   s += "\nMagic          :   " + IntegerToString(Magic);
   s += "\nSpred          :   " + DoubleToString(spread, 0);
   s += "\nRSI             :   " + DoubleToString(rsi_curr, 2);
   s += "\nRSI-1          :   " + DoubleToString(rsi_preview, 2);
   s += "\nStep          :   " + DoubleToString(last_price, 5);
   if(ExpertStop) s += "\nExpert           :  OFF";
   //if(!ExpertStop && !license) s += "\nExpert   :  ON";
   s += "\n\n\n";
   s += "\nEnvelopes UP    :   " + DoubleToString(env_up_befor, 5);
   s += "\nEnvelopes LOW  :   " + DoubleToString(env_low_befor, 5);
   s += "\nBuls                  :  " + DoubleToString(buls_befor, 5);
   s += "\nBears                :  " + DoubleToString(bears_befor, 5);

   Comment(s);

   if(!ExpertStop)
   {
      if (CountTrades() < MaxTrades)
      {
         if (a_symbol.Ask() < env_low_befor)
         {
            if (rsi_curr < buy_level && (bears_befor < buls_befor)) // rsi_curr <= 30 && (rsi_curr - rsi_preview) >= 2
            {
               OpenBuy(o_lots);
            }
            if (rsi_preview > 50 && rsi_curr < 50)
            {
               // OpenSell(o_lots);
               Print("рассмотреть доп условие на продажу");
            }
         }
      }

      if (CountTrades() < MaxTrades)
      {
         if (a_symbol.Ask() > env_up_befor)
         {
            if (rsi_curr > sell_level && (buls_befor > bears_befor)) // rsi_curr > 70 && (rsi_preview - rsi_curr) >= 2
            {
               OpenSell(o_lots);
            }
            if (rsi_preview < 50 && rsi_curr > 50)
            {
               // OpenBuy(o_lots);
               Print("рассмотреть доп условие на покупку");
            }
         }
      }

      // Connect MartinGile
      if (Martingale)
      {
         if (last_price != 0 && last_pos_type >= 0 && last_lots != 0)
         {
            if (last_pos_type == POSITION_TYPE_BUY)
            {
               if (a_symbol.Ask() <= last_price - eStep)
               {
                  double next_lots = CalcLots(last_lots * Multiplier);

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
                  double next_lots = CalcLots(last_lots * Multiplier);

                  if (next_lots != 0)
                  {
                     OpenSell(next_lots);
                     return;
                  }
               }
            }
         }
      }
      else
      {
      /*if (CountTrades() > 0 && rsi_preview >= 50 && rsi_curr < 50)
         CloseOrder();

      if (CountTrades() > 0 && rsi_preview <= 50 && rsi_curr > 50)
         CloseOrder();
         */
      if (CountTrades() > 0 && ORDER_TYPE_BUY)
      {
         if (rsi_curr > 70) // (rsi_preview < 50 && rsi_curr > 50) ||
            CloseOrder();
      }

      if (CountTrades() > 0 && ORDER_TYPE_SELL)
      {
         if (rsi_curr < 30) // (rsi_preview > 50 && rsi_curr < 50) ||
            CloseOrder();
      }
      }
   }
}
//+------------------------------------------------------------------+
void TrailingStop()
// Функция позволяет тралить stoploss
{

   double  StopLoss = a_symbol.NormalizePrice(TralingStep * a_symbol.Point());

   if(CountTrades() >= 1)
     {
      for(int i = PositionsTotal() - 1; i >= 0; i--)
        {
            ENUM_POSITION_TYPE type = a_pos.PositionType();
            double CurrSL = a_pos.StopLoss();
            double OpenPrice = a_pos.PriceOpen();
            double CurrPrice = a_pos.PriceCurrent();

            if (a_pos.SelectByIndex(i))
            {
               if(type == POSITION_TYPE_BUY && a_pos.Magic() == Magic && CurrPrice > OpenPrice + StopLoss)  // && CurrPrice > OpenPrice + StopLoss
                 {
                  if(CurrPrice - StopLoss > CurrSL || CurrSL == 0)
                    {
                     a_trade.PositionModify(a_pos.Ticket(), NormalizeDouble((a_symbol.Bid() - StopLoss), a_symbol.Digits()), 0);
                    }
                 }

               if(type == POSITION_TYPE_SELL && a_pos.Magic() == Magic && CurrPrice < OpenPrice - StopLoss)  // && CurrPrice < OpenPrice - StopLoss
                 {
                  if(CurrPrice + StopLoss < CurrSL || CurrSL == 0)
                    {
                     a_trade.PositionModify(a_pos.Ticket(), NormalizeDouble((a_symbol.Ask() + StopLoss),  a_symbol.Digits()), 0);
                    }
                 }
            }
        }
     }
}
//+------------------------------------------------------------------+
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
//| Close position orders                                            |
//+------------------------------------------------------------------+
void CloseOrder()
{
   for (int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.Symbol() == a_symbol.Name() && a_pos.Magic() == Magic)
         {
            a_trade.PositionClose(a_pos.Ticket());
            Print("Ордер успешно закрыт!");
         }
      }
   }
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
double CalcProfit(ENUM_POSITION_TYPE pos_type)
{
   double _profit = 0;

   for (int i = PositionsTotal() -1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.PositionType() == pos_type && a_pos.Magic() == Magic && a_pos.Symbol() == a_symbol.Name())
         {
            _profit += a_pos.Profit();
         }
      }
   }

   return(_profit);
}
//+------------------------------------------------------------------+
double BalansProfit()
// Функция подсчитывает профит всех сделок текущего советника;
// return: _profit (double) - подсчитанный профит;
{
   double _profit = 0;
   ulong  _ticket = 0;

   if (!HistorySelect(0, TimeCurrent()))
      Print("Не удалось загрузить историю");

   for(int i = 1; i < HistoryDealsTotal(); i++)
     {
      if ((_ticket = HistoryDealGetTicket(i)) > 0 )
      {
         if (HistoryDealGetInteger(_ticket, DEAL_MAGIC) == Magic)
         {
            _profit += HistoryDealGetDouble(_ticket, DEAL_PROFIT);
         }
      }
      /*if (a_pos.SelectByIndex(i))
      {
         if (a_pos.Magic() == Magic && a_pos.Symbol() == a_symbol.Name())
         {
            _profit += a_pos.Profit();
         }
      }*/
     }
   return _profit;
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
double LotsBuyRisk(int op_tipe, double risk, int _sl)
// Расчитывает лот для сделки от профита, по установленному риску и размеру StopLoss;
// param: op_type (int) - направление сделки;
// param: risk (double) - риски в %;
// param: _sl (int)     - Stoploss в пунктах для расчета лота;
// return: lot (double) - возвращаемое значение нового лота;
{
   double lot_min  = a_symbol.LotsMin();    // определение значения минимального лота
   double lot_max  = a_symbol.LotsMax();    // определение значения максимального лота
   double lot_step = a_symbol.LotsStep();   // определение значение шага лота
   double lotcost  = a_symbol.TickValue();  // определение стоимости лота
   double lot = 0;
   double UsdPerPip = 0;                    // определение денег на один пункт

   lot = profit * risk / 100;               //расчет по отношению объема и стоплосса
   UsdPerPip = lot / _sl;                   //полученный объем делим на стоплосс

   lot = NormalizeDouble(UsdPerPip / lotcost, 2);
   lot = NormalizeDouble(lot / lot_step, 0) * lot_step;

   if(lot < lot_min)
      lot = lot_min;
   if(lot > lot_max)
      lot = lot_max;

   return(lot);
}
//+------------------------------------------------------------------+
int CountTrades()
// Функция подсчитывает ордера которые в рынке;
// return: int (count) - количество открытых ордеров;
{
   int count = 0;

   for (int i = PositionsTotal() -1; i >= 0; i--)
   {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.Symbol() == a_symbol.Name() && a_pos.Magic() == Magic)
         {
            if (a_pos.PositionType() == POSITION_TYPE_BUY || a_pos.PositionType() == POSITION_TYPE_SELL)
               count++;
               // last_price = a_pos.PriceOpen();
         }
      }
   }
   return(count);
}
//+------------------------------------------------------------------+
double GetBufferIndicator(int handle,int buffer, int start_pos, int count)
// Функция копирует данные индикатора с графика.
// Принимает значения:
// param: handle (int)     - хендл индикатора;
// param: buffer (int)     - номер буфера индикатора;
// param: start_pos (int)  - начало позиции;
// param: count (int)      - размер масива (количество баров);
// return: buffer (double) - значение уровня индикатора;
{
   double buffInd[1];
   ResetLastError();

   if (CopyBuffer(handle, buffer, start_pos, count, buffInd) < 0)
   {
      Print("Не удалось скопировать данные индикатора! " + IntegerToString(handle));
      return(0);
   }
   return(buffInd[0]);
}
//+------------------------------------------------------------------+
bool RefreshRates()
// Функция позволяет обновить катировки, в случае успешного действия возвращается true;
// return: bool - true || false ;
{
   if (!a_symbol.RefreshRates())
   {
      Print("Не удалось обновить катировки!");
      return(false);
   }
   if (a_symbol.Ask() == 0 || a_symbol.Bid() == 0)
   {
      Print("Нет цены!");
      return(false);
   }
   return(true);
}
//+------------------------------------------------------------------+
