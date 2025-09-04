#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>
#include <Trade\OrderInfo.mqh>

CPositionInfo  a_pos;
CTrade         a_trade;
CSymbolInfo    a_symbol;
COrderInfo     a_order;

//+------------------------------------------------------------------+
//|                                                        Maxan.mq5 |
//|                                                         Martynov |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Martynov"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description    "Подстройки для скальпинга:";
#property description    "EUR m5 Body = 135";
#property description    "GBP m5 Body = 185";
#property description    "GBP m1 Body = 115";
#property description    "Gold m5 Body = 300-345";
#property description    "Gold m1 Body = 215";
#property description    "EUR m5 step = 24 // GBP m5  step = 35 // Gold m5 step = 60";
#property description    "EUR m5 mini = 12 // GBP m5  mini = 20 // Gold m5 mini = 53-55";
#property description    "";

//+------------------------------------------------------------------+
//| Inputs Variable                                                  |
//+------------------------------------------------------------------+
input string  Name         = "Maxan"; // Название советника
input bool    UseMM        = true;  // Управление Maney Management
input int     MaxTrades    = 1;     // Количество ордеров для сделок
input double  RiskLot      = 2;     // Нагрузка на дипозит в %
input double  RiskStop     = 5;     // Риск Stoploss от дипозита в %
input double  Lot          = 0.01;  // Размер лота
input double  MaxLot       = 10;    // Максимальный размера лота
input string  _            = " Scalping ";    // Настройки для скальпинга
input int     StopLoss     = 30;    // StopLoss для скальпинга
input int     Trailing     = 1;     // TralingStop в пунктах
input int     Body         = 135;   // Размер тело свечи
input int     StepOrder    = 5;     // Шаг для удаления отложенного ордера
input int     OpenPosition = 1;     // Устновка отложенного ордера от цены
input string  Martingale   = " Martingale ";    // Настройки для Мартингейла
input int     Step         = 100;   // Шаг открытия след ордера
input int     Profit       = 20;    // Profit для закрытия сделки
input double  Multiplier   = 2;     // Множитель для след лота
input string  __           = "";    // Настройки советника
input int     TryCount     = 10;    // Количество попыток для открытия ордера
input int     Magic        = 0;     // Магический номер советника
input int     Slippage     = 10;    // Проскальзивание
input bool    ExpertStop   = false; // Ручное отклюсение советника
input int     work_spread  = 11;    // Уровень рабочего спреда
//+------------------------------------------------------------------+
input string  ___          = " Stochastic ";   // Настройки индикатора
input int     KPeriod      = 9;
input int     DPeriod      = 3;
input int     Slowing      = 3;
//+------------------------------------------------------------------+
input string  ____         = " Envelopes ";    // Настройки индикатора
input double  Deviation    = 0.05;
//+------------------------------------------------------------------+
input string  _____        = " BulsPower ";    // Настройки индикатора
//+------------------------------------------------------------------+
input string  ______       = " BearsPower ";   // Настройки индикатора
//+------------------------------------------------------------------+
int aStoch, aBuls, aBears, env_up, env_low;
double Lots;

ulong levelBuls  = 240;
ulong levelBears = 240;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if (!a_symbol.Name(Symbol())) return(INIT_FAILED);
   
   RefreshRates();
   
   a_trade.SetExpertMagicNumber(Magic);
   a_trade.SetMarginMode();
   a_trade.SetTypeFillingBySymbol(a_symbol.Name());
   a_trade.SetDeviationInPoints(Slippage);
   
   env_up = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, 14, 0, MODE_LWMA, MODE_HIGH, Deviation);
   env_low = iEnvelopes(a_symbol.Name(),PERIOD_CURRENT, 14, 0, MODE_LWMA, MODE_LOW, Deviation);
   
   aBuls  = iBullsPower(a_symbol.Name(), PERIOD_CURRENT, 13);
   aBears = iBearsPower(a_symbol.Name(), PERIOD_CURRENT, 13);
   
   aStoch = iStochastic(a_symbol.Name(), PERIOD_CURRENT, KPeriod, DPeriod, Slowing, MODE_SMA, STO_LOWHIGH);
   
   if (env_up == INVALID_HANDLE || env_low == INVALID_HANDLE)
   {
      Print("Не удалось получить описатель индикатора Envelopes.\nОписание ошибки: " + IntegerToString(GetLastError()));
      return(INIT_FAILED);
   }
   if(aBuls == INVALID_HANDLE)
   {
      Print("Не удалось получить описатель индикатора BulsPower.\nОписание ошибки: " + IntegerToString(GetLastError()));
      return(INIT_FAILED);
   }
   if(aBears == INVALID_HANDLE)
   {
      Print("Не удалось получить описатель индикатора BersPower.\nОписание ошибки: " + IntegerToString(GetLastError()));
      return(INIT_FAILED);
   }
   if(aStoch == INVALID_HANDLE)
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
   
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   if (!RefreshRates()) return;
   
   double buyPoint  = NormalizeDouble(levelBuls * a_symbol.Point(), _Digits);
   double sellPoint = NormalizeDouble(levelBears * a_symbol.Point(), _Digits);
   
   double env_up_befor = GetBufferIndicator(env_up, MODE_HIGH, 1, 1);
   double env_low_befor = GetBufferIndicator(env_low, MODE_LOW, 1, 1);
   
   double buls_befor = GetBufferIndicator(aBuls, 0, 1, 1);
   double bears_befor = GetBufferIndicator(aBears, 0, 1, 1);
   
   double stoch_main = GetBufferIndicator(aStoch, MAIN_LINE, 1, 1);
   double stoch_signal = GetBufferIndicator(aStoch, SIGNAL_LINE, 1, 1);
   
   if(!ExpertStop)
   {
      if (CountTrades() == 0)
      {
         if (BuyStop() == 0)
         {
            Print("Отложенные ордера отсутствуют");
         }
         if (a_symbol.Ask() > env_up) Print("");
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
//---
   
  }
//+------------------------------------------------------------------+
double GetBufferIndicator(int handle,int buffer_num, int start_pos, int count)
// Функция копирует данные индикатора с графика.
// Принимает значения:
// - handle     - хендл индикатора;
// - buffer_num - номер буфера индикатора;
// - start_pos  - начало позиции;
// - count      - размер масива (количество баров);
// Возвращает значение цены бара по индексу (buffer_num)
{
   double buffer[1];
   ResetLastError();
   
   if (CopyBuffer(handle, buffer_num, start_pos, count, buffer) < 0)
   {
      Print("Не удалось скопировать данные индикатора!");
      return(0);
   }
   return(buffer[0]);
}
//+------------------------------------------------------------------+
bool RefreshRates()
// Функция позволяет обновить катировки
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