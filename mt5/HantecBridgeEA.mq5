//+------------------------------------------------------------------+
//|                                              HantecBridgeEA.mq5  |
//|               Copyright 2026, TradingView Webhook Algo Platform |
//|                                             https://iqsync.in   |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, TradingView Webhook Algo Platform"
#property link      "https://iqsync.in"
#property version   "1.00"
#property description "Hantec MT5 Expert Advisor for TradingView Webhook Node.js Backend"

#include <Trade\Trade.mqh>

//--- Input Parameters
input string   InpServerURL        = "https://apitrading.iqsync.in"; // Node.js Backend Server URL
input int      InpPollIntervalMs   = 500;                     // Polling Interval (ms)
input string   InpDefaultSymbol    = "BTC";                   // Default Trading Symbol
input ulong    InpMagicNumber      = 123456;                  // EA Magic Number
input string   InpEAToken          = "hantec_mt5_secret";     // EA Authorization Token
input ulong    InpSlippage         = 20;                      // Max Slippage Points
input bool     InpAutoSyncAccount  = true;                    // Sync Account Telemetry

//--- Global Objects & Variables
CTrade         trade;
datetime       lastSyncTime        = 0;
ulong          lastProcessedDeal   = 0;

//+------------------------------------------------------------------+
//| Symbol Normalization Helper                                      |
//+------------------------------------------------------------------+
string NormalizeSymbol(string sym)
{
   string upper = sym;
   StringToUpper(upper);
   if(upper == "" || upper == "BTCUSD" || upper == "BTCUSDT" || upper == "BITSTAMPBTCUSD" || upper == "BINANCEBTCUSDT" || StringFind(upper, "BTC") == 0)
   {
      return "BTC";
   }
   return upper;
}

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("🚀 Initializing Hantec MT5 Bridge EA for ", InpDefaultSymbol);
   Print("🌐 Target Backend: ", InpServerURL);

   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(InpSlippage);
   trade.SetTypeFillingBySymbol(InpDefaultSymbol);

   // Start millisecond timer for fast polling
   if(!EventSetMillisecondTimer(InpPollIntervalMs))
   {
      Print("❌ Failed to set millisecond timer!");
      return(INIT_FAILED);
   }

   Print("✅ Hantec Bridge EA initialized successfully.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   Print("🛑 Hantec Bridge EA stopped. Reason code: ", reason);
}

//+------------------------------------------------------------------+
//| Expert timer function (Polls Backend & Syncs State)             |
//+------------------------------------------------------------------+
void OnTimer()
{
   // 1. Poll Backend for Pending Orders
   PollPendingOrders();

   // 2. Periodic Account Telemetry Sync (Every 5 Seconds)
   if(InpAutoSyncAccount && (TimeCurrent() - lastSyncTime >= 5))
   {
      SendAccountSync();
      lastSyncTime = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
//| Helper to perform WebRequest HTTP GET/POST                       |
//+------------------------------------------------------------------+
bool SendHttpRequest(string method, string urlPath, string jsonBody, string &outResponse)
{
   char data[];
   char result[];
   string resultHeaders;
   string headers = "Content-Type: application/json\r\nx-ea-token: " + InpEAToken + "\r\n";

   int bodyLen = StringLen(jsonBody);
   if(bodyLen > 0)
   {
      StringToCharArray(jsonBody, data, 0, bodyLen, CP_UTF8);
   }

   string fullUrl = InpServerURL + urlPath;
   ResetLastError();

   int res = WebRequest(method, fullUrl, headers, 3000, data, result, resultHeaders);
   if(res == 200 || res == 201 || res == 202)
   {
      outResponse = CharArrayToString(result, 0, WHOLE_ARRAY, CP_UTF8);
      return true;
   }
   else
   {
      Print("⚠️ WebRequest failed [Method: ", method, " Path: ", urlPath, " HTTP Code: ", res, " Err: ", GetLastError(), "]");
      return false;
   }
}

//+------------------------------------------------------------------+
//| Poll pending orders from Node.js backend                         |
//+------------------------------------------------------------------+
void PollPendingOrders()
{
   string response;
   if(!SendHttpRequest("GET", "/api/mt5/pending-orders", "", response)) return;

   if(StringFind(response, "\"orders\":[") < 0 || StringFind(response, "\"orders\":[]") >= 0) return;

   // Parse pending orders from JSON payload
   ProcessOrdersJson(response);
}

//+------------------------------------------------------------------+
//| Process JSON array of pending orders                             |
//+------------------------------------------------------------------+
void ProcessOrdersJson(string json)
{
   // Simple string parser for demo reliability
   int pos = 0;
   while((pos = StringFind(json, "{\"orderId\":", pos)) >= 0)
   {
      int endPos = StringFind(json, "}", pos);
      if(endPos < 0) break;

      string orderObj = StringSubstr(json, pos, endPos - pos + 1);
      pos = endPos + 1;

      string orderId = ExtractJsonValue(orderObj, "orderId");
      string tradeId = ExtractJsonValue(orderObj, "tradeId");
      string type    = ExtractJsonValue(orderObj, "type");
      string symbol  = ExtractJsonValue(orderObj, "symbol");
      string action  = ExtractJsonValue(orderObj, "action");
      double volume  = StringToDouble(ExtractJsonValue(orderObj, "volume"));
      double price   = StringToDouble(ExtractJsonValue(orderObj, "price"));
      double sl      = StringToDouble(ExtractJsonValue(orderObj, "sl"));
      double tp      = StringToDouble(ExtractJsonValue(orderObj, "tp"));
      if(tp <= 0) tp  = StringToDouble(ExtractJsonValue(orderObj, "target"));
      ulong  ticket       = StringToInteger(ExtractJsonValue(orderObj, "ticket"));
      ulong  closeTicket  = StringToInteger(ExtractJsonValue(orderObj, "closeTicket"));
      string closeTradeId = ExtractJsonValue(orderObj, "closeTradeId");

      symbol = NormalizeSymbol(symbol);
      if(volume <= 0)  volume = 1.0;
      if(symbol == "BTC") volume = 1.0;

      if(type == "OPEN")
      {
         ExecuteOpenOrder(orderId, tradeId, symbol, action, volume, 0, 0);
      }
      else if(type == "REVERSE")
      {
         ExecuteReverseOrder(orderId, tradeId, closeTradeId, closeTicket, symbol, action, volume);
      }
      else if(type == "CLOSE")
      {
         ExecuteCloseOrder(orderId, tradeId, ticket);
      }
   }
}

//+------------------------------------------------------------------+
//| Execute Atomic Position Reversal (Close existing + Open new)      |
//+------------------------------------------------------------------+
void ExecuteReverseOrder(string orderId, string tradeId, string closeTradeId, ulong closeTicket, string symbol, string action, double volume)
{
   symbol = NormalizeSymbol(symbol);
   if(symbol == "BTC") volume = 1.0;
   trade.SetTypeFillingBySymbol(symbol);
   Print("🔄 REVERSAL SIGNAL: Closing Ticket #", closeTicket, " and Opening ", action, " ", volume, " ", symbol);

   if(closeTicket > 0 && PositionSelectByTicket(closeTicket))
   {
      double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit     = PositionGetDouble(POSITION_PROFIT);
      bool closeSuccess = trade.PositionClose(closeTicket);

      if(closeSuccess)
      {
         Print("✅ Reversal Exit Successful! Closed Ticket: ", closeTicket, " Close Price: ", closePrice, " PnL: ", profit);
         SendTradeClosed(closeTradeId, closeTicket, closePrice, profit, "REVERSAL_EXIT");
      }
      else
      {
         string errorDesc = StringFormat("Reversal Close Failed for Ticket %I64u. ErrCode: %d, RetCode: %d", closeTicket, GetLastError(), trade.ResultRetcode());
         Print("❌ ", errorDesc);
         SendExecutionResult(orderId, tradeId, 0, 0, "FAILED", errorDesc);
         return; // 🛑 STRICT REVERSAL SAFETY: DO NOT OPEN NEW POSITION IF CLOSE FAILED!
      }
   }
   else if(closeTicket > 0)
   {
      Print("ℹ️ Ticket #", closeTicket, " no longer exists (already closed). Proceeding with reversal entry...");
   }

   // Open new position ONLY if close succeeded or position was already closed
   ExecuteOpenOrder(orderId, tradeId, symbol, action, volume, 0, 0);
}

//+------------------------------------------------------------------+
//| Execute BUY / SELL market order on MT5                           |
//+------------------------------------------------------------------+
void ExecuteOpenOrder(string orderId, string tradeId, string symbol, string action, double volume, double sl, double tp)
{
   symbol = NormalizeSymbol(symbol);
   if(symbol == "BTC") volume = 1.0;
   trade.SetTypeFillingBySymbol(symbol);
   Print("⚡ Executing Market ", action, " Order for ", symbol, " Volume: ", volume, " SL: ", sl, " TP: ", tp);

   bool success = false;
   if(action == "BUY")
   {
      double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
      if(symbol == "BTC") volume = 1.0;
      success = trade.Buy(volume, symbol, ask, sl, tp, "TV_WEBHOOK_" + tradeId);
   }
   else if(action == "SELL")
   {
      double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
      if(symbol == "BTC") volume = 1.0;
      success = trade.Sell(volume, symbol, bid, sl, tp, "TV_WEBHOOK_" + tradeId);
   }

   ulong resultTicket = trade.ResultOrder();
   double fillPrice   = trade.ResultPrice();

   if(success && resultTicket > 0)
   {
      Print("✅ Order Filled! Ticket: ", resultTicket, " Price: ", fillPrice);
      SendExecutionResult(orderId, tradeId, resultTicket, fillPrice, "FILLED", "");
   }
   else
   {
      string errorDesc = StringFormat("ErrCode: %d, RetCode: %d", GetLastError(), trade.ResultRetcode());
      Print("❌ Order Placement Failed: ", errorDesc);
      SendExecutionResult(orderId, tradeId, 0, 0, "FAILED", errorDesc);
   }
}

//+------------------------------------------------------------------+
//| Execute Position Close on MT5                                    |
//+------------------------------------------------------------------+
void ExecuteCloseOrder(string orderId, string tradeId, ulong ticket)
{
   Print("⚡ Closing MT5 Position Ticket: ", ticket);

   bool success = false;
   if(ticket > 0 && PositionSelectByTicket(ticket))
   {
      string posSymbol = PositionGetString(POSITION_SYMBOL);
      if(posSymbol != "") trade.SetTypeFillingBySymbol(posSymbol);
      double closePrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double profit     = PositionGetDouble(POSITION_PROFIT);
      success           = trade.PositionClose(ticket);

      if(success)
      {
         Print("✅ Position Closed! Ticket: ", ticket, " Close Price: ", closePrice, " PnL: ", profit);
         SendTradeClosed(tradeId, ticket, closePrice, profit, "MANUAL_EXIT");
         SendExecutionResult(orderId, tradeId, ticket, closePrice, "SUCCESS", "");
         return;
      }
   }

   Print("⚠️ Position Ticket ", ticket, " not found or already closed.");
   SendTradeClosed(tradeId, ticket, 0, 0, "ALREADY_CLOSED");
   SendExecutionResult(orderId, tradeId, ticket, 0, "FAILED", "Position Not Found");
}

//+------------------------------------------------------------------+
//| Callback: Send Order Execution Result to Backend                 |
//+------------------------------------------------------------------+
void SendExecutionResult(string orderId, string tradeId, ulong ticket, double fillPrice, string status, string comment)
{
   string json = StringFormat(
      "{\"orderId\":\"%s\",\"tradeId\":\"%s\",\"ticket\":%I64u,\"fillPrice\":%.2f,\"status\":\"%s\",\"comment\":\"%s\"}",
      orderId, tradeId, ticket, fillPrice, status, comment
   );
   string response;
   SendHttpRequest("POST", "/api/mt5/execution-result", json, response);
}

//+------------------------------------------------------------------+
//| Callback: Send Closed Trade Result & Realized PnL to Backend     |
//+------------------------------------------------------------------+
void SendTradeClosed(string tradeId, ulong ticket, double exitPrice, double pnl, string reason)
{
   string json = StringFormat(
      "{\"tradeId\":\"%s\",\"ticket\":%I64u,\"exitPrice\":%.2f,\"pnl\":%.2f,\"reason\":\"%s\"}",
      tradeId, ticket, exitPrice, pnl, reason
   );
   string response;
   SendHttpRequest("POST", "/api/mt5/trade-closed", json, response);
}

//+------------------------------------------------------------------+
//| Callback: Send Account Telemetry Sync to Backend                 |
//+------------------------------------------------------------------+
void SendAccountSync()
{
   double balance    = AccountInfoDouble(ACCOUNT_BALANCE);
   double equity     = AccountInfoDouble(ACCOUNT_EQUITY);
   double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   long   login      = AccountInfoInteger(ACCOUNT_LOGIN);
   string server     = AccountInfoString(ACCOUNT_SERVER);

   string json = StringFormat(
      "{\"account\":{\"login\":%I64d,\"server\":\"%s\",\"balance\":%.2f,\"equity\":%.2f,\"freeMargin\":%.2f}}",
      login, server, balance, equity, freeMargin
   );
   string response;
   SendHttpRequest("POST", "/api/mt5/sync", json, response);
}

//+------------------------------------------------------------------+
//| Helper to parse simple JSON string values                        |
//+------------------------------------------------------------------+
string ExtractJsonValue(string json, string key)
{
   string pattern = "\"" + key + "\":";
   int pos = StringFind(json, pattern);
   if(pos < 0) return "";

   int start = pos + StringLen(pattern);
   // Skip whitespace
   while(start < StringLen(json) && (StringSubstr(json, start, 1) == " " || StringSubstr(json, start, 1) == "\""))
   {
      start++;
   }

   int end = start;
   while(end < StringLen(json))
   {
      string ch = StringSubstr(json, end, 1);
      if(ch == "\"" || ch == "," || ch == "}") break;
      end++;
   }

   return StringSubstr(json, start, end - start);
}

//+------------------------------------------------------------------+
//| Transaction event handler (Detects automated SL/TP hits on MT5) |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans, const MqlTradeRequest &request, const MqlTradeResult &result)
{
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      ulong dealTicket = trans.deal;
      if(dealTicket == lastProcessedDeal) return;

      lastProcessedDeal = dealTicket;
      long entry = HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

      // Entry OUT means position closed (SL, TP, or manual close)
      if(entry == DEAL_ENTRY_OUT)
      {
         ulong  positionId = HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID);
         double exitPrice  = HistoryDealGetDouble(dealTicket, DEAL_PRICE);
         double profit     = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
         long   reasonCode = HistoryDealGetInteger(dealTicket, DEAL_REASON);

         string reason = "CLOSED";
         if(reasonCode == DEAL_REASON_SL) reason = "SL_HIT";
         else if(reasonCode == DEAL_REASON_TP) reason = "TARGET_HIT";

         Print("🚨 MT5 Position Closed Event Detected! Ticket: ", positionId, " PnL: ", profit, " Reason: ", reason);
         SendTradeClosed("", positionId, exitPrice, profit, reason);
      }
   }
}
//+------------------------------------------------------------------+
