//+------------------------------------------------------------------+
//|                                              © Scalper_ES v4.mq4 |
//|                                       Copyright 2025, V Martynov |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2025, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict
#property description    "EUR m5 Body = 135";
#property description    "GBP m5 Body = 185";
#property description    "GBP m1 Body = 115";
#property description    "Gold m5 Body = 300-345";
#property description    "Gold m1 Body = 215";
#property description    "EUR m5 step = 24 // GBP m5  step = 35 // Gold m5 step = 60";
#property description    "EUR m5 mini = 12 // GBP m5  mini = 20 // Gold m5 mini = 53-55";
#property description    "";

extern string  Name         = "© Scalper_ES v4"; // Название советника
extern bool    UseMM        = true;  // Управление maney managmen
extern int     MaxTrades    = 1;     // Количество отложенных ордеров
extern double  RiskLot      = 2;     // Управление риском дипозита в %
extern double  Lot          = 0.01;  // Размер лота
extern double  MaxLot       = 10;    // Максимальный размера лота
extern int     StopLoss     = 30;
extern int     Trailing     = 1;     // TralingStop в пунктах
extern int     Body         = 135;   // Размер тело свечи
extern int     StepOrder    = 5;     // Шаг для удаления отложенного ордера
extern int     OpenPosition = 1;     // Устновка отложенного ордера от цены
extern int     TryCount     = 10;    // Количество попыток для открытия ордера
extern int     Magic        = 0;     // Магический номер советника
extern bool    ExpertStop   = false; // Ручное отклюсение советника
//+------------------------------------------------------------------+
int  ticket;
double ma1_1, ma1_2, ma2_1, ma2_2, Lots, m0, m1, sl, o_price, profit;

int buy_tick[];
int sell_tick[];
//+------------------------------------------------------------------+
struct candle
  {
   //параметры свечи
   double             open, close, high, low, body; //цены
   bool bullish, bear, doji, big; //вид свечи: бычья, медвежья, доджи (без тела), большая белая/черная
   datetime           t; //время свечи
   double             up_shadow, down_shadow; //верхняя и нижняя тени
   //функция инициализирует параметры свечи, принимая в качестве аргумента индекс значения из таймсерии
   void              load(int i)
     {
      bullish = false;
      bear = false;
      doji = false;
      big = false;
      open  = NormalizeDouble(iOpen(Symbol(), Period(), i), Digits); //цена открытия
      close = NormalizeDouble(iClose(Symbol(), Period(), i), Digits); //цена закрытия
      high  = NormalizeDouble(iHigh(Symbol(), Period(), i), Digits); //максимальная цена
      low   = NormalizeDouble(iLow(Symbol(), Period(), i), Digits); //минимальная цена
      t     = iTime(Symbol(), Period(), i); //время закрытия
      body  = MathAbs(close - open); //размер тела
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
   ma1_1 = iEnvelopes(Symbol(), 0, 14, MODE_LWMA, 0, PRICE_HIGH, 0.05, MODE_UPPER, 0);
   ma1_2 = iEnvelopes(Symbol(), 0, 14, MODE_LWMA, 0, PRICE_HIGH, 0.05, MODE_LOWER, 0);

   ma2_1 = iEnvelopes(Symbol(), 0, 14, MODE_LWMA, 0, PRICE_LOW, 0.05, MODE_UPPER, 0);
   ma2_2 = iEnvelopes(Symbol(), 0, 14, MODE_LWMA, 0, PRICE_LOW, 0.05, MODE_LOWER, 0);


   m0 = NormalizeDouble(ma2_2 - 0 * Point, Digits);
   m1 = NormalizeDouble(ma1_1 + 0 * Point, Digits);

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
   candle c1, c2, c3;
   c1.load(2);
   c2.load(1);
   c3.load(0);

// if(TimeCurrent() > StrToTime("2020.12.29"))
//   {
//   Comment("                 СРОК ЛИЦЕНЗИИ ИСТЕК !!!");
//   return;
//   }
   profit = BalansProfit();
   TrailingStop(buy_tick, sell_tick);

   if (UseMM)
   {
      Lots = NormalizeDouble(LotsBuyRisk(RiskLot, StopLoss), 2);
   }
   else Lots = Lot;

   if(Lots >= MaxLot)
      Lots = MaxLot;

   int Key = MarketInfo(Symbol(),MODE_SPREAD);
   if(Magic == 0)
      Magic += Period() + Key;

   double body_size = 0;
   body_size = NormalizeDouble(Body * Point, Digits); //средний арифметический размер тела из выборки на глубину depth

   double spred = MarketInfo(Symbol(), MODE_SPREAD);
   string s = "";
   s += "\nLOT     : " + DoubleToStr(Lots, 2);
   s += "\nBalans  : " + DoubleToStr(AccountBalance(), 2);
   s += "\nEquity  : " + DoubleToStr(AccountEquity(), 2);
   s += "\nMagic   : " + IntegerToString(Magic);
   s += "\nSpred   : " + DoubleToStr(spred, 0);
   s += "\nProfit    : " + DoubleToStr(profit,2);
   if(Digits == 5 s += "\nBody    : " + DoubleToStr(c3.body * 100000, 0);
   if(Digits == 3) s += "\nBody    : " + DoubleToStr(c3.body * 1000, 0);
   if(Digits == 2) s += "\nBody    : " + DoubleToStr(c3.body * 100, 0);
   if(ExpertStop == true)
      s += "\nExpert   :  OFF";
   if(ExpertStop == false)
      s += "\nExpert   :  ON";

   Comment(s);
   if(ExpertStop == false)
     {
      if( here is the entry condition )
        {

         double price = NormalizeDouble(Ask + OpenPosition * Point, Digits);
         sl = NormalizeDouble(Ask - StopLoss * Point, Digits);

         ticket = OrderSendx(Symbol(), OP_BUYSTOP, Lots, price, 5, sl, 0, "", Magic, 0, clrAqua);
         SendNotification("© Scalper_ES v4 : - Выставил ордер на покупку " + "<< " + Symbol() + "  M" + IntegerToString(Period()) + " >>");
         Alert("© Scalper_ES v4 : - Покупка, покупка !!!" + Symbol() + IntegerToString(Period()));
        }
      o_price = LastOpenOrder(OP_BUYSTOP);
      if(o_price >= 1)
        {
         if(Ask < (o_price - StepOrder * Point))
           {
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                 {
                  if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_BUYSTOP)
                    {
                     if(OrderDelete(OrderTicket()))
                        Print("Удалился ордер BUYSTOP");
                    }
                 }
              }

           }
        }
      if( here is the entry condition )
        {

         double price = NormalizeDouble(Bid - OpenPosition * Point, Digits);
         sl = NormalizeDouble(Bid + StopLoss * Point, Digits);

         ticket = OrderSendx(Symbol(), OP_SELLSTOP, Lots, price, 5, sl, 0, "", Magic, 0, clrBrown);
         SendNotification("© Scalper_ES v4 : - Выставил ордер на продажу " + "<< " + Symbol() + "  M" + IntegerToString(Period()) + " >>");
         Alert("© Scalper_ES v4 : - Продажа, продажа !!!" + Symbol() + IntegerToString(Period()));
        }
      o_price = LastOpenOrder(OP_SELLSTOP);
      if(o_price >= 1)
        {
         if(Bid > (o_price + StepOrder * Point))
           {
            for(int i = OrdersTotal() - 1; i >= 0; i--)
              {
               if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
                 {
                  if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_SELLSTOP)
                    {
                     if(OrderDelete(OrderTicket()))
                        Print("Удалился ордер SELLSTOP");
                    }
                 }
              }

           }
        }
     }
   else
      return;
}
//+------------------------------------------------------------------+
int OrderSendx(string   symbol,               // символ
               int      cmd,                 // торговая операция
               double   volume,              // количество лотов
               double   price,               // цена
               int      slippage,            // проскальзывание
               double   stoploss,            // stop loss
               double   takeprofit,          // take profit
               string   comment = NULL,      // комментарий
               int      magic = 0,           // идентификатор
               datetime expiration = 0,      // срок истечения ордера
               color    arrow_color = clrNONE // цвет
              )
  {
   int err = GetLastError();
   err = 0;

   bool exit_loop = false;   // выход из цикла
   int cnt = 0;              // счетчик для попыток открытия ордера

   while(!exit_loop)
     {
      if(IsTradeAllowed())
        {
         ticket = OrderSend(symbol, cmd, volume, price, slippage, stoploss, takeprofit,  comment, magic, expiration, arrow_color);
         err = GetLastError();
        }

      switch(err)
        {
         case ERR_NO_ERROR:
            exit_loop = true;
            break;

         case ERR_SERVER_BUSY:
         case ERR_NO_CONNECTION:
         case ERR_INVALID_PRICE:
         case ERR_OFF_QUOTES:
         case ERR_BROKER_BUSY:
         case ERR_TRADE_CONTEXT_BUSY:
         case ERR_TRADE_TIMEOUT:
            cnt++;
            break;

         case ERR_PRICE_CHANGED:
         case ERR_REQUOTE:
            RefreshRates();
            continue;

         default:
            exit_loop = true;
            break;

        }   //  switch(err)

      if(cnt > TryCount)
         exit_loop = true;      // выход из цикла при превышении попыток открыть ордер

      if(!exit_loop)
        {
         //volume = volume + MarketInfo(Symbol(),MODE_MINLOT);
         Sleep(1500);
         RefreshRates();
        }

      if(exit_loop)
        {
         if(err != ERR_NO_ERROR)
           {
            Print("Ошибка: " + IntegerToString(err));
           }
        }

      if(err == ERR_NO_ERROR)
        {
         if(OrderSelect(ticket, SELECT_BY_TICKET, MODE_TRADES))
            return(ticket);
         else
            return(-1);
        }

      Print("Ошибка открытия после " + IntegerToString(cnt) + " попыток");
      Print("Ошибка : " + IntegerToString(err));

     }   //  while(!exit_loop)

   return(-1);
  }
//+------------------------------------------------------------------+
int CountTrades()
  {
   int  count = 0;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
           {
            if(OrderType() == OP_BUY || OrderType() == OP_SELL)
               count ++;
           }
        }
     }
   return(count);
  }
//+------------------------------------------------------------------+
int BuyStop()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= MaxTrades - 1; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_BUYSTOP)
            count ++;
        }
     }
   return(count);
  }
//+------------------------------------------------------------------+
int SellStop()
  {
   int count = 0;
   for(int i = OrdersTotal() - 1; i >= MaxTrades - 1; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == OP_SELLSTOP)
            count ++;
        }
     }
   return(count);
  }
//+------------------------------------------------------------------+
double LotsBuyRisk(double risk, int _sl)
  {
   double lot_min  = MarketInfo(Symbol(), MODE_MINLOT);    // определение значения минимального лота
   double lot_max  = MarketInfo(Symbol(), MODE_MAXLOT);    // определение значения максимального лота
   double lot_step = MarketInfo(Symbol(), MODE_LOTSTEP);   // определение значение шага лота
   double lotcost  = MarketInfo(Symbol(), MODE_TICKVALUE); // определение стоимости лота
   double lot = 0;
   double UsdPerPip = 0;   // определение денег на один пункт

   lot = profit * risk / 100; //расчет по отношению объема и стоплосса
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
void TrailingStop(int &buy[], int &sell[])
  {
   ArrayFree(buy);
   ArrayFree(sell);
   for(int i = OrdersTotal() - 1;  i >= 0; i--)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic)
           {
            if(OrderType() == OP_BUY)
              {
               ArrayResize(buy, ArraySize(buy) + 1, 12);
               buy[ArraySize(buy) - 1] = OrderTicket();
               if(Bid >= OrderOpenPrice() + Trailing * Point)
                 {
                  if((StopLoss * Point) < (Bid + OrderOpenPrice()))
                    {
                     if((Bid - Trailing * Point) > OrderStopLoss())
                       {
                        if(OrderStopLoss() <= sl)
                           sl = NormalizeDouble((Bid - Trailing * Point), Digits);

                        if(!OrderModify(OrderTicket(), OrderOpenPrice(), sl, 0, 0))
                           Print("1");
                       }
                    }
                 }
              }
            if(OrderType() == OP_SELL)
              {
               ArrayResize(sell, ArraySize(sell) + 1, 12);
               sell[ArraySize(sell) - 1] = OrderTicket();
               if(Ask <= OrderOpenPrice() - Trailing * Point)
                 {
                  if((StopLoss * Point) < (OrderOpenPrice() + Ask))
                    {
                     if((Ask + Trailing * Point) < OrderStopLoss())
                       {
                        if(OrderStopLoss() >= sl)
                           sl = NormalizeDouble((Ask + Trailing * Point), Digits);

                        if(!OrderModify(OrderTicket(), OrderOpenPrice(), sl, 0, 0))
                           Print("2");
                       }
                    }
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
double LastOpenOrder(int otype)
  {
   int oldticket;
   double oldopenprice = 0;
   ticket = 0;
   for(int cnt = OrdersTotal() - 1; cnt >= 0; cnt --)
     {
      if(OrderSelect(cnt, SELECT_BY_POS, MODE_TRADES))
        {
         if(OrderSymbol() == Symbol() && OrderMagicNumber() == Magic && OrderType() == otype)
           {
            oldticket = OrderTicket();
            if(oldticket > ticket)
              {
               ticket = oldticket;
               oldopenprice = OrderOpenPrice();
              }
           }
        }
     }
   return (oldopenprice);

  }
//+------------------------------------------------------------------+
double BalansProfit()
{
   double _profit = 0;
   for(int i = 0; i < OrdersHistoryTotal(); i++)
     {
      if(OrderSelect(i, SELECT_BY_POS, MODE_HISTORY))
        {
          _profit += OrderSwap() + OrderProfit();
        }
     }
  return _profit;
}
//+------------------------------------------------------------------+
