//+------------------------------------------------------------------+
//|                                                        Maxan.mq5 |
//|                                  Copyright 2025, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "© Martynov"
#property link      "https://github.com/vikneo?tab=repositories"
#property version   "v 1.00"
#property description "Maxan - советник построен на основе работы Мартин Гейла"
#property description "советник работает на любой паре и с любым тайм-фреймом";
#property description "- управление по времени";
#property description "- управление по ограничению баланса";
#property description "- управление риском в процентном соотношении от баланса";

#include <Trade\PositionInfo.mqh>   //  подключаем модуль для получения информации о наших позициях
#include <Trade\Trade.mqh>          //  подключаем модуль для Торговли
#include <Trade\SymbolInfo.mqh>     //  подключаем модуль для получения информации о валютной паре

CPositionInfo     apos;
CTrade            atrade;
CSymbolInfo       asymbol;

input double    Lots          = 1;
input int       TakeProfit    = 25;
input int       Step          = 35;
input double    Multiplier    = 2;
input int       Magic         = 8765;
input int       Slippag       = 3;
input int       MaxOrder      = 3;
input int       MaxLoss       = 40;
double Balans = ACCOUNT_BALANCE;
//+------------------------------------------------------------------+
int TMA;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{

   TMA = iCustom(asymbol.Name(), Period(), "TMA_line_indicator");
   if(TMA == INVALID_HANDLE)
   {
       Print("Не удалось создать инициализацию индикатора 'Stochastic Oscillator'!");
       return(INIT_FAILED);
   }
   Print("TMA = " + IntegerToString(TMA));
   Print(Balans);
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



}
//+------------------------------------------------------------------+
