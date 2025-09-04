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
input double  RiskLots     = 2;     // Нагрузка на дипозит в %
input double  RiskStop     = 5;     // Риск Stoploss от дипозита в %
input double  Lots         = 0.01;  // Размер лота
input double  MaxLots      = 10;    // Максимальный размера лота
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
double o_lots, profit;

ulong levelBuls  = 240;
ulong levelBears = 240;
//+------------------------------------------------------------------+
struct candle
{
   //параметры свечи
   double open, close, high, low, body;
   bool   bullish, bear, doji, big; //вид свечи: бычья, медвежья, доджи (без тела), большая белая/черная
   datetime t;                      //время свечи
   double up_shadow, down_shadow;   //верхняя и нижняя тени

   //функция инициализирует параметры свечи, принимая в качестве аргумента индекс значения из таймсерии
   void load(int i)
   {
      bullish = false;
      bear = false;
      doji = false;
      big = false;
      open = NormalizeDouble(iOpen(a_symbol.Name(), PERIOD_CURRENT, i), _Digits);
      close = NormalizeDouble(iClose(a_symbol.Name(), PERIOD_CURRENT, i), _Digits);
      high = NormalizeDouble(iHigh(a_symbol.Name(), PERIOD_CURRENT, i), _Digits);
      low = NormalizeDouble(iLow(a_symbol.Name(), PERIOD_CURRENT, i), _Digits);
      t = iTime(a_symbol.Name(), PERIOD_CURRENT, i);
      body = MathAbs(close - open);

      //проверка на "бычье тело"
      if(close > open)
        {
         bullish = true;         //бычье тело
         up_shadow = high - close; //верхняя тень
         down_shadow = open - low; //нижняя тень
        }
      //проверка на "медвежье тело"
      if(close < open)
        {
         bear = true;             //медвежье тело
         up_shadow = high - open; //верхняя тень
         down_shadow = close - low; //нижняя тень
        }
      //проверка на доджи - свеча без тела
      if(close == open)
        {
         doji = true;            //счеча без тела - доджи
         up_shadow = high - close; //верхняя тень
         down_shadow = open - low; //нижняя тень
        }
      //проверка на большую свечу (размер тела минимум в 2 раза больше размера теней)
      if(body >= 2 * (up_shadow + down_shadow))
         big = true;
   }
};
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
   candle c3;
   c3.load(0);

   profit = BalansProfit();

   if (!RefreshRates()) return;

   if (UseMM)
   {
      o_lots = NormalizeDouble(LotsBuyRisk(CountTrades(), RiskLots, StopLoss), 2);
      if (o_lots >= MaxLots) o_lots = MaxLots;
   }
   else o_lots = Lots;

   double BulsPoint  = NormalizeDouble(levelBuls * a_symbol.Point(), _Digits);
   double BearsPoint = NormalizeDouble(-1  * (levelBears * a_symbol.Point()), _Digits);

   double env_up_befor = GetBufferIndicator(env_up, UPPER_LINE, 1, 1);
   double env_low_befor = GetBufferIndicator(env_low, LOWER_LINE, 1, 1);

   double buls_befor = GetBufferIndicator(aBuls, 0, 1, 1);
   double bears_befor = GetBufferIndicator(aBears, 0, 1, 1);

   double stoch_main = GetBufferIndicator(aStoch, MAIN_LINE, 1, 1);
   double stoch_signal = GetBufferIndicator(aStoch, SIGNAL_LINE, 1, 1);

   if(!ExpertStop)
   {
      if (CountTrades() == 0)
      {
         if (a_symbol.Ask() < env_low_befor)
         {
            if (bears_befor < BearsPoint)
            {
               if (stoch_signal < 20) // добавить условие на доп уточнение для покупки
               {
                  if (a_trade.Buy(o_lots, a_symbol.Name(), a_symbol.Ask(), 0, 0))
                  {
                     Print("Установлен ордер на покупку!");
                     Alert("Куплено - " + a_symbol.Name(), " По цене - " + DoubleToString(a_symbol.Ask()));
                  }
               }
            }
            if (DeferrOrderStop() == 0 && c3.body > Body)
            {
               // if (a_trade.BuyStop(o_lots, _price, a_symbol.Name(), o_sl, 0, 0, 0, "Buy Stop"))
               Print("Установлен отложенный ордер на покупку!");
            }
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

}
//+------------------------------------------------------------------+
int DeferrOrderStop()
{
   int count = 0;

   for (int i = OrdersTotal() - 1; i >= MaxTrades - 1; i--)
   {
      if (a_order.SelectByIndex(i))
      {
         if (a_order.Symbol() == a_symbol.Name() && a_order.Magic() == Magic)
            count ++;
      }
   }
   return(count);
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
double BalansProfit()
{
   double _profit = 0;
   for(int i = 0; i < OrdersTotal(); i++)
     {
      if (a_pos.SelectByIndex(i))
      {
         if (a_pos.Magic() == Magic && a_pos.Symbol() == a_symbol.Name())
         {
            _profit += a_pos.Profit();
         }
      }
     }
   return _profit;
}
//+------------------------------------------------------------------+
double LotsBuyRisk(int op_tipe, double risk, int _sl)
{
   double lot_min  = a_symbol.LotsMin();    // определение значения минимального лота
   double lot_max  = a_symbol.LotsMax();    // определение значения максимального лота
   double lot_step = a_symbol.LotsStep();   // определение значение шага лота
   double lotcost  = a_symbol.TickValue();  // определение стоимости лота
   double lot = 0;
   double UsdPerPip = 0;   // определение денег на один пункт

   lot = ACCOUNT_BALANCE * risk / 100; //расчет по отношению объема и стоплосса
   UsdPerPip = lot / _sl;               //полученный объем делим на стоплосс

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
         }
      }
   }
   return(count);
}
//+------------------------------------------------------------------+
double GetBufferIndicator(int handle,int buffer_num, int start_pos, int count)
// Функция копирует данные индикатора с графика.
// Принимает значения:
// param: handle (int)     - хендл индикатора;
// param: buffer_num (int) - номер буфера индикатора;
// param: start_pos (int)  - начало позиции;
// param: count (int)      - размер масива (количество баров);
// return: buffer (double) - значение уровня индикатора;
{
   double buffer[1];
   ResetLastError();

   if (CopyBuffer(handle, buffer_num, start_pos, count, buffer) < 0)
   {
      Print("Не удалось скопировать данные индикатора! " + IntegerToString(handle));
      return(0);
   }
   return(buffer[0]);
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