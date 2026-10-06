//+------------------------------------------------------------------+
//|                                              HantecBridgeEA.mq5  |
//|               Copyright 2026, TradingView Webhook Algo Platform |
//|                                             https://iqsync.in   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, TradingView Webhook Algo Platform"
#property link      "https://iqsync.in"
#property version   "2.00"
#property description "Hantec MT5 Expert Advisor for TradingView Webhook Node.js Backend"

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Input Parameters                                                  |
//+------------------------------------------------------------------+
input string   InpServerURL        = "https://apitrading.iqsync.in";
input int      InpPollIntervalMs   = 500;
input string   InpDefaultSymbol    = "BTCUSD";
input ulong    InpMagicNumber      = 123456;
input string   InpEAToken          = "hantec_mt5_secret";
input ulong    InpSlippage         = 20;
input bool     InpAutoSyncAccount  = true;

//+------------------------------------------------------------------+
//| Global Objects & Variables                                       |
//+------------------------------------------------------------------+
CTrade   trade;

datetime lastSyncTime      = 0;
ulong    lastProcessedDeal = 0;

//+------------------------------------------------------------------+
//| Normalize symbol                                                 |
//+------------------------------------------------------------------+
string NormalizeSymbol(string sym)
{
   string upper = sym;

   StringToUpper(upper);

   if(upper == "" ||
      upper == "BTC" ||
      upper == "BTCUSD" ||
      upper == "BTCUSDT" ||
      upper == "BITSTAMPBTCUSD" ||
      upper == "BINANCEBTCUSDT")
   {
      return "BTCUSD";
   }

   return upper;
}

//+------------------------------------------------------------------+
//| Expert initialization                                            |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=================================================");
   Print("🚀 Initializing Hantec MT5 Bridge EA");
   Print("📊 Default Symbol: ", InpDefaultSymbol);
   Print("🌐 Backend: ", InpServerURL);
   Print("🔢 Magic Number: ", InpMagicNumber);
   Print("=================================================");

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(InpDefaultSymbol);

   if(!EventSetMillisecondTimer(InpPollIntervalMs))
   {
      Print("❌ Failed to set millisecond timer!");
      return(INIT_FAILED);
   }

   Print("✅ Hantec Bridge EA initialized successfully.");

   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization                                          |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();

   Print(
      "🛑 Hantec Bridge EA stopped. Reason code: ",
      reason
   );
}

//+------------------------------------------------------------------+
//| Timer                                                             |
//+------------------------------------------------------------------+
void OnTimer()
{
   PollPendingOrders();

   if(InpAutoSyncAccount &&
      (TimeCurrent() - lastSyncTime >= 5))
   {
      SendAccountSync();

      lastSyncTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| HTTP Request                                                      |
//+------------------------------------------------------------------+
bool SendHttpRequest(
   string method,
   string urlPath,
   string jsonBody,
   string &outResponse
)
{
   char data[];
   char result[];

   string resultHeaders;

   string headers =
      "Content-Type: application/json\r\n"
      "x-ea-token: " + InpEAToken + "\r\n";

   int bodyLen = StringLen(jsonBody);

   if(bodyLen > 0)
   {
      StringToCharArray(
         jsonBody,
         data,
         0,
         bodyLen,
         CP_UTF8
      );
   }

   string fullUrl = InpServerURL + urlPath;

   ResetLastError();

   int res = WebRequest(
      method,
      fullUrl,
      headers,
      3000,
      data,
      result,
      resultHeaders
   );

   if(res == 200 ||
      res == 201 ||
      res == 202)
   {
      outResponse =
         CharArrayToString(
            result,
            0,
            WHOLE_ARRAY,
            CP_UTF8
         );

      return true;
   }

   Print(
      "⚠️ WebRequest failed | Method: ",
      method,
      " | Path: ",
      urlPath,
      " | HTTP: ",
      res,
      " | Error: ",
      GetLastError()
   );

   return false;
}

//+------------------------------------------------------------------+
//| Poll pending orders                                               |
//+------------------------------------------------------------------+
void PollPendingOrders()
{
   string response;

   if(!SendHttpRequest(
      "GET",
      "/api/mt5/pending-orders",
      "",
      response))
   {
      return;
   }

   if(
      StringFind(
         response,
         "\"orders\":["
      ) < 0
   )
   {
      return;
   }

   if(
      StringFind(
         response,
         "\"orders\":[]"
      ) >= 0
   )
   {
      return;
   }

   ProcessOrdersJson(response);
}

//+------------------------------------------------------------------+
//| Process pending orders                                            |
//+------------------------------------------------------------------+
void ProcessOrdersJson(string json)
{
   int pos = 0;

   while(
      (pos =
         StringFind(
            json,
            "{\"orderId\":",
            pos
         )) >= 0
   )
   {
      int endPos =
         StringFind(
            json,
            "}",
            pos
         );

      if(endPos < 0)
         break;

      string orderObj =
         StringSubstr(
            json,
            pos,
            endPos - pos + 1
         );

      pos = endPos + 1;

      string orderId =
         ExtractJsonValue(
            orderObj,
            "orderId"
         );

      string tradeId =
         ExtractJsonValue(
            orderObj,
            "tradeId"
         );

      string type =
         ExtractJsonValue(
            orderObj,
            "type"
         );

      string symbol =
         ExtractJsonValue(
            orderObj,
            "symbol"
         );

      string action =
         ExtractJsonValue(
            orderObj,
            "action"
         );

      double volume =
         StringToDouble(
            ExtractJsonValue(
               orderObj,
               "volume"
            )
         );

      double price =
         StringToDouble(
            ExtractJsonValue(
               orderObj,
               "price"
            )
         );

      double sl =
         StringToDouble(
            ExtractJsonValue(
               orderObj,
               "sl"
            )
         );

      double tp =
         StringToDouble(
            ExtractJsonValue(
               orderObj,
               "tp"
            )
         );

      if(tp <= 0)
      {
         tp =
            StringToDouble(
               ExtractJsonValue(
                  orderObj,
                  "target"
               )
            );
      }

      ulong ticket =
         (ulong)StringToInteger(
            ExtractJsonValue(
               orderObj,
               "ticket"
            )
         );

      ulong closeTicket =
         (ulong)StringToInteger(
            ExtractJsonValue(
               orderObj,
               "closeTicket"
            )
         );

      string closeTradeId =
         ExtractJsonValue(
            orderObj,
            "closeTradeId"
         );

      symbol = NormalizeSymbol(symbol);

      if(volume <= 0)
         volume = 1.0;

      // -------------------------------------------------------------
      // OPEN
      // -------------------------------------------------------------

      if(type == "OPEN")
      {
         ExecuteOpenOrder(
            orderId,
            tradeId,
            symbol,
            action,
            volume,
            sl,
            tp
         );
      }

      // -------------------------------------------------------------
      // REVERSE
      // -------------------------------------------------------------

      else if(type == "REVERSE")
      {
         ExecuteReverseOrder(
            orderId,
            tradeId,
            closeTradeId,
            closeTicket,
            symbol,
            action,
            volume
         );
      }

      // -------------------------------------------------------------
      // CLOSE
      // -------------------------------------------------------------

      else if(type == "CLOSE")
      {
         ExecuteCloseOrder(
            orderId,
            tradeId,
            ticket
         );
      }
   }
}

//+------------------------------------------------------------------+
//| Find current EA position                                         |
//+------------------------------------------------------------------+
bool GetCurrentPosition(
   string symbol,
   ulong &ticket,
   ENUM_POSITION_TYPE &positionType,
   double &volume
)
{
   ticket = 0;
   volume = 0;

   for(
      int i = PositionsTotal() - 1;
      i >= 0;
      i--
   )
   {
      ulong currentTicket =
         PositionGetTicket(i);

      if(currentTicket == 0)
         continue;

      string currentSymbol =
         PositionGetString(
            POSITION_SYMBOL
         );

      if(currentSymbol != symbol)
         continue;

      long magic =
         PositionGetInteger(
            POSITION_MAGIC
         );

      if((ulong)magic != InpMagicNumber)
         continue;

      ticket = currentTicket;

      positionType =
         (ENUM_POSITION_TYPE)
         PositionGetInteger(
            POSITION_TYPE
         );

      volume =
         PositionGetDouble(
            POSITION_VOLUME
         );

      return true;
   }

   return false;
}

//+------------------------------------------------------------------+
//| Execute reversal                                                 |
//|                                                                  |
//| BUY -> SELL                                                       |
//| SELL -> BUY                                                       |
//| BUY -> BUY = ignore                                              |
//| SELL -> SELL = ignore                                             |
//| No position -> open requested direction                          |
//+------------------------------------------------------------------+
void ExecuteReverseOrder(
   string orderId,
   string tradeId,
   string closeTradeId,
   ulong closeTicket,
   string symbol,
   string action,
   double volume
)
{
   symbol = NormalizeSymbol(symbol);

   trade.SetTypeFillingBySymbol(symbol);

   Print(
      "🔄 SIGNAL: ",
      action,
      " ",
      symbol
   );

   // -------------------------------------------------------------
   // Find actual position in MT5
   // -------------------------------------------------------------

   ulong currentTicket = 0;

   ENUM_POSITION_TYPE currentType;

   double currentVolume = 0;

   bool hasPosition =
      GetCurrentPosition(
         symbol,
         currentTicket,
         currentType,
         currentVolume
      );

   // -------------------------------------------------------------
   // NO POSITION
   // -------------------------------------------------------------

   if(!hasPosition)
   {
      Print(
         "ℹ️ No existing position. Opening ",
         action
      );

      ExecuteOpenOrder(
         orderId,
         tradeId,
         symbol,
         action,
         volume,
         0,
         0
      );

      return;
   }

   // -------------------------------------------------------------
   // SAME DIRECTION
   // -------------------------------------------------------------

   if(
      action == "BUY" &&
      currentType == POSITION_TYPE_BUY
   )
   {
      Print(
         "ℹ️ BUY already exists. ",
         "Ignoring duplicate BUY."
      );

      SendExecutionResult(
         orderId,
         tradeId,
         currentTicket,
         0,
         "IGNORED",
         "BUY already exists"
      );

      return;
   }

   if(
      action == "SELL" &&
      currentType == POSITION_TYPE_SELL
   )
   {
      Print(
         "ℹ️ SELL already exists. ",
         "Ignoring duplicate SELL."
      );

      SendExecutionResult(
         orderId,
         tradeId,
         currentTicket,
         0,
         "IGNORED",
         "SELL already exists"
      );

      return;
   }

   // -------------------------------------------------------------
   // OPPOSITE DIRECTION
   // -------------------------------------------------------------

   double closePrice =
      PositionGetDouble(
         POSITION_PRICE_CURRENT
      );

   double profit =
      PositionGetDouble(
         POSITION_PROFIT
      );

   Print(
      "🔄 Closing existing position #",
      currentTicket,
      " before opening ",
      action
   );

   bool closeSuccess =
      trade.PositionClose(
         currentTicket
      );

   if(!closeSuccess)
   {
      string errorDesc =
         StringFormat(
            "Reversal Close Failed | Ticket: %I64u | Error: %d | RetCode: %d",
            currentTicket,
            GetLastError(),
            trade.ResultRetcode()
         );

      Print(
         "❌ ",
         errorDesc
      );

      SendExecutionResult(
         orderId,
         tradeId,
         0,
         0,
         "FAILED",
         errorDesc
      );

      return;
   }

   Print(
      "✅ Reversal Exit Successful!",
      " Ticket: ",
      currentTicket,
      " Close Price: ",
      closePrice,
      " PnL: ",
      profit
   );



   // -------------------------------------------------------------
   // VERIFY POSITION REALLY CLOSED
   // -------------------------------------------------------------

   bool stillOpen = true;

   for(int i = 0; i < 10; i++)
   {
      Sleep(100);

      if(!PositionSelectByTicket(currentTicket))
      {
         stillOpen = false;
         break;
      }
   }

   if(stillOpen)
   {
      Print(
         "❌ Old position still exists.",
         " New position will NOT be opened."
      );

      SendExecutionResult(
         orderId,
         tradeId,
         0,
         0,
         "FAILED",
         "Old position still open after close verification"
      );

      return;
   }

   // -------------------------------------------------------------
   // OPEN NEW DIRECTION
   // -------------------------------------------------------------

   Print(
      "🚀 Opening new ",
      action,
      " position."
   );

   ExecuteOpenOrder(
      orderId,
      tradeId,
      symbol,
      action,
      volume,
      0,
      0
   );
}

//+------------------------------------------------------------------+
//| Execute BUY / SELL market order                                  |
//+------------------------------------------------------------------+
void ExecuteOpenOrder(
   string orderId,
   string tradeId,
   string symbol,
   string action,
   double volume,
   double sl,
   double tp
)
{
   symbol = NormalizeSymbol(symbol);

   trade.SetTypeFillingBySymbol(symbol);

   // -------------------------------------------------------------
   // SAFETY CHECK
   // -------------------------------------------------------------

   ulong currentTicket = 0;

   ENUM_POSITION_TYPE currentType;

   double currentVolume = 0;

   bool hasPosition =
      GetCurrentPosition(
         symbol,
         currentTicket,
         currentType,
         currentVolume
      );

   // -------------------------------------------------------------
   // Duplicate protection
   // -------------------------------------------------------------

   if(
      action == "BUY" &&
      hasPosition &&
      currentType == POSITION_TYPE_BUY
   )
   {
      Print(
         "⚠️ Duplicate BUY blocked. ",
         "Existing Ticket: ",
         currentTicket
      );

      SendExecutionResult(
         orderId,
         tradeId,
         currentTicket,
         0,
         "IGNORED",
         "Duplicate BUY blocked"
      );

      return;
   }

   if(
      action == "SELL" &&
      hasPosition &&
      currentType == POSITION_TYPE_SELL
   )
   {
      Print(
         "⚠️ Duplicate SELL blocked. ",
         "Existing Ticket: ",
         currentTicket
      );

      SendExecutionResult(
         orderId,
         tradeId,
         currentTicket,
         0,
         "IGNORED",
         "Duplicate SELL blocked"
      );

      return;
   }

   // -------------------------------------------------------------
   // Never allow two opposite positions
   // -------------------------------------------------------------

   if(hasPosition)
   {
      Print(
         "❌ SAFETY BLOCK: Existing opposite position #",
         currentTicket,
         " still exists."
      );

      SendExecutionResult(
         orderId,
         tradeId,
         currentTicket,
         0,
         "FAILED",
         "Opposite position still exists"
      );

      return;
   }

   // -------------------------------------------------------------
   // Volume
   // -------------------------------------------------------------

   if(volume <= 0)
      volume = 1.0;

   // -------------------------------------------------------------
   // Execute
   // -------------------------------------------------------------

   Print(
      "⚡ Executing Market ",
      action,
      " Order for ",
      symbol,
      " Volume: ",
      volume,
      " SL: ",
      sl,
      " TP: ",
      tp
   );

   bool success = false;

   // -------------------------------------------------------------
   // BUY
   // -------------------------------------------------------------

   if(action == "BUY")
   {
      double ask =
         SymbolInfoDouble(
            symbol,
            SYMBOL_ASK
         );

      if(ask <= 0)
      {
         Print(
            "❌ Invalid BTCUSD ASK price."
         );

         return;
      }

      success =
         trade.Buy(
            volume,
            symbol,
            ask,
            sl,
            tp,
            "TV_WEBHOOK_" + tradeId
         );
   }

   // -------------------------------------------------------------
   // SELL
   // -------------------------------------------------------------

   else if(action == "SELL")
   {
      double bid =
         SymbolInfoDouble(
            symbol,
            SYMBOL_BID
         );

      if(bid <= 0)
      {
         Print(
            "❌ Invalid BTCUSD BID price."
         );

         return;
      }

      success =
         trade.Sell(
            volume,
            symbol,
            bid,
            sl,
            tp,
            "TV_WEBHOOK_" + tradeId
         );
   }

   // -------------------------------------------------------------
   // Unknown action
   // -------------------------------------------------------------

   else
   {
      Print(
         "❌ Unknown trading action: ",
         action
      );

      return;
   }

   // -------------------------------------------------------------
   // Result
   // -------------------------------------------------------------

   ulong resultTicket =
      trade.ResultOrder();

   double fillPrice =
      trade.ResultPrice();

   if(
      success &&
      resultTicket > 0
   )
   {
      Print(
         "✅ Order Filled!",
         " Ticket: ",
         resultTicket,
         " Price: ",
         fillPrice
      );

      SendExecutionResult(
         orderId,
         tradeId,
         resultTicket,
         fillPrice,
         "FILLED",
         ""
      );
   }
   else
   {
      string errorDesc =
         StringFormat(
            "ErrCode: %d, RetCode: %d",
            GetLastError(),
            trade.ResultRetcode()
         );

      Print(
         "❌ Order Placement Failed: ",
         errorDesc
      );

      SendExecutionResult(
         orderId,
         tradeId,
         0,
         0,
         "FAILED",
         errorDesc
      );
   }
}

//+------------------------------------------------------------------+
//| Execute position close                                           |
//+------------------------------------------------------------------+
void ExecuteCloseOrder(
   string orderId,
   string tradeId,
   ulong ticket
)
{
   Print(
      "⚡ Closing MT5 Position Ticket: ",
      ticket
   );

   if(
      ticket == 0 ||
      !PositionSelectByTicket(ticket)
   )
   {
      Print(
         "⚠️ Position Ticket ",
         ticket,
         " not found."
      );

      SendTradeClosed(
         tradeId,
         ticket,
         0,
         0,
         "ALREADY_CLOSED"
      );

      SendExecutionResult(
         orderId,
         tradeId,
         ticket,
         0,
         "IGNORED",
         "Position not found"
      );

      return;
   }

   string posSymbol =
      PositionGetString(
         POSITION_SYMBOL
      );

   if(posSymbol != "")
   {
      trade.SetTypeFillingBySymbol(
         posSymbol
      );
   }

   double closePrice =
      PositionGetDouble(
         POSITION_PRICE_CURRENT
      );

   double profit =
      PositionGetDouble(
         POSITION_PROFIT
      );

   bool success =
      trade.PositionClose(
         ticket
      );

   if(success)
   {
      Print(
         "✅ Position Closed!",
         " Ticket: ",
         ticket,
         " Close Price: ",
         closePrice,
         " PnL: ",
         profit
      );

      SendTradeClosed(
         tradeId,
         ticket,
         closePrice,
         profit,
         "MANUAL_EXIT"
      );

      SendExecutionResult(
         orderId,
         tradeId,
         ticket,
         closePrice,
         "SUCCESS",
         ""
      );

      return;
   }

   string errorDesc =
      StringFormat(
         "Position Close Failed | Error: %d | RetCode: %d",
         GetLastError(),
         trade.ResultRetcode()
      );

   Print(
      "❌ ",
      errorDesc
   );

   SendExecutionResult(
      orderId,
      tradeId,
      ticket,
      0,
      "FAILED",
      errorDesc
   );
}

//+------------------------------------------------------------------+
//| Send execution result                                            |
//+------------------------------------------------------------------+
void SendExecutionResult(
   string orderId,
   string tradeId,
   ulong ticket,
   double fillPrice,
   string status,
   string comment
)
{
   string json =
      StringFormat(
         "{\"orderId\":\"%s\","
         "\"tradeId\":\"%s\","
         "\"ticket\":%I64u,"
         "\"fillPrice\":%.2f,"
         "\"status\":\"%s\","
         "\"comment\":\"%s\"}",
         orderId,
         tradeId,
         ticket,
         fillPrice,
         status,
         comment
      );

   string response;

   SendHttpRequest(
      "POST",
      "/api/mt5/execution-result",
      json,
      response
   );
}

//+------------------------------------------------------------------+
//| Send closed trade                                                |
//+------------------------------------------------------------------+
void SendTradeClosed(
   string tradeId,
   ulong ticket,
   double exitPrice,
   double pnl,
   string reason
)
{
   string json =
      StringFormat(
         "{\"tradeId\":\"%s\","
         "\"ticket\":%I64u,"
         "\"exitPrice\":%.2f,"
         "\"pnl\":%.2f,"
         "\"reason\":\"%s\"}",
         tradeId,
         ticket,
         exitPrice,
         pnl,
         reason
      );

   string response;

   SendHttpRequest(
      "POST",
      "/api/mt5/trade-closed",
      json,
      response
   );
}

//+------------------------------------------------------------------+
//| Account telemetry                                                |
//+------------------------------------------------------------------+
void SendAccountSync()
{
   double balance =
      AccountInfoDouble(
         ACCOUNT_BALANCE
      );

   double equity =
      AccountInfoDouble(
         ACCOUNT_EQUITY
      );

   double freeMargin =
      AccountInfoDouble(
         ACCOUNT_MARGIN_FREE
      );

   long login =
      AccountInfoInteger(
         ACCOUNT_LOGIN
      );

   string server =
      AccountInfoString(
         ACCOUNT_SERVER
      );

   string json =
      StringFormat(
         "{\"account\":{"
         "\"login\":%I64d,"
         "\"server\":\"%s\","
         "\"balance\":%.2f,"
         "\"equity\":%.2f,"
         "\"freeMargin\":%.2f"
         "}}",
         login,
         server,
         balance,
         equity,
         freeMargin
      );

   string response;

   SendHttpRequest(
      "POST",
      "/api/mt5/sync",
      json,
      response
   );
}

//+------------------------------------------------------------------+
//| Extract JSON value                                               |
//+------------------------------------------------------------------+
string ExtractJsonValue(
   string json,
   string key
)
{
   string pattern =
      "\"" + key + "\":";

   int pos =
      StringFind(
         json,
         pattern
      );

   if(pos < 0)
      return "";

   int start =
      pos + StringLen(pattern);

   while(
      start < StringLen(json) &&
      (
         StringSubstr(
            json,
            start,
            1
         ) == " " ||

         StringSubstr(
            json,
            start,
            1
         ) == "\""
      )
   )
   {
      start++;
   }

   int end = start;

   while(
      end < StringLen(json)
   )
   {
      string ch =
         StringSubstr(
            json,
            end,
            1
         );

      if(
         ch == "\"" ||
         ch == "," ||
         ch == "}"
      )
      {
         break;
      }

      end++;
   }

   return StringSubstr(
      json,
      start,
      end - start
   );
}

//+------------------------------------------------------------------+
//| Trade transaction event                                          |
//+------------------------------------------------------------------+
void OnTradeTransaction(
   const MqlTradeTransaction &trans,
   const MqlTradeRequest &request,
   const MqlTradeResult &result
)
{
   if(
      trans.type !=
      TRADE_TRANSACTION_DEAL_ADD
   )
   {
      return;
   }

   ulong dealTicket =
      trans.deal;

   if(
      dealTicket ==
      lastProcessedDeal
   )
   {
      return;
   }

   lastProcessedDeal =
      dealTicket;

   long entry =
      HistoryDealGetInteger(
         dealTicket,
         DEAL_ENTRY
      );

   // -------------------------------------------------------------
   // Position closed
   // -------------------------------------------------------------

   if(
      entry ==
      DEAL_ENTRY_OUT
   )
   {
      ulong positionId =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_POSITION_ID
         );

      double exitPrice =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PRICE
         );

      double profit =
         HistoryDealGetDouble(
            dealTicket,
            DEAL_PROFIT
         );

      long reasonCode =
         HistoryDealGetInteger(
            dealTicket,
            DEAL_REASON
         );

      string reason =
         "CLOSED";

      if(
         reasonCode ==
         DEAL_REASON_SL
      )
      {
         reason = "SL_HIT";
      }
      else if(
         reasonCode ==
         DEAL_REASON_TP
      )
      {
         reason = "TARGET_HIT";
      }

      Print(
         "🚨 MT5 Position Closed Event",
         " | Ticket: ",
         positionId,
         " | PnL: ",
         profit,
         " | Reason: ",
         reason
      );

      SendTradeClosed(
         "",
         positionId,
         exitPrice,
         profit,
         reason
      );
   }
}
//+------------------------------------------------------------------+