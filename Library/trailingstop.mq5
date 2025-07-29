// Source code viewer
// -----------------------------------------------------
// Загружаем классы из библиотеки <Trade>

#include <Trade\PositionInfo.mqh>
#include <Trade\Trade.mqh>

// -----------------------------------------------------
// Создаем экземпляры классов

CPosition   a_pos;
CTrade      a_trade;

// -----------------------------------------------------
// Задаем входные параметры

input bool      trailing        = true; // даем разрешение на тралл stopLoss
input int       SLPoints        = 100;  // кол-во поинтов для тралла

// -----------------------------------------------------
// объявим переменные

double  StopLoss = SLPoints * Points();
int     PosCount = PositionsTotal();

// -----------------------------------------------------
void TrailingStop()
// Функция позволяет тралить stoploss
{
    if (trailing && PosCount > 1)
    {
        for (int i = PosCount - 1; i >= 0; i--)
        {
            ENUM_POSITION_TYPE type = a_pos.PositionType();
            double CurrSL = a_pos.StopLoss();
            double CurrTP = a_pos.TakeProfit();
            double CurrPrice = a_pos.PriceCurrent();

            if (type == POSITION_TYPE_BUY)
            {
                if (CurrPrice - StopLoss > CurrSL || CurrSL == 0)
                {
                    a_trade.PositionModify(a_pos.Ticket(), NormalizeDouble((CurrPrice - StopLoss), Digits()), 0)
                }
            }

            if (type == POSITION_TYPE_SELL)
            {
                if (CurrPrice + StopLoss < CurrSL || CurrSL == 0)
                {
                    a_trade.PositionModify(a_pos.Ticket(), NormalizeDouble((CurrPrice + StopLoss), Digits()), 0)
                }
            }
        }
    }
}
// -----------------------------------------------------