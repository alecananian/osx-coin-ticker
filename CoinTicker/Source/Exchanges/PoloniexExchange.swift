//
//  PoloniexExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/9/18.
//  Copyright © 2018 Alec Ananian.
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//

import Foundation
import Starscream
import SwiftyJSON

class PoloniexExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://api2.poloniex.com:443")!
        static let TickerAPIPath = "https://poloniex.com/public?command=returnTicker"
        static let TickerChannel = 1002
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .poloniex, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.TickerAPIPath) {
            $0.json.compactMap { currencyJSON in
                let currencyCodes = currencyJSON.0.split(separator: "_")
                guard currencyCodes.count == 2, let baseCurrency = currencyCodes.last, let quoteCurrency = currencyCodes.first else {
                    return nil
                }
                
                return CurrencyPair(
                    baseCurrency: String(baseCurrency),
                    quoteCurrency: String(quoteCurrency),
                    customCode: currencyJSON.1["id"].stringValue
                )
            }
        }
    }
    
    override internal func fetch() {
        requestAPI(Constants.TickerAPIPath).map { [weak self] result in
            if let strongSelf = self {
                for (_, result) in result.json {
                    if let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: result["id"].stringValue) {
                        strongSelf.setPrice(result["last"].doubleValue, for: currencyPair)
                    }
                }
                
                if strongSelf.isUpdatingInRealTime {
                    strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                } else {
                    strongSelf.onFetchComplete()
                }
            }
        }.catch { error in
            print("Error fetching Poloniex ticker: \(error)")
        }
        
        if isUpdatingInRealTime {
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = socketResponseQueue
            
            socket.onConnect = {
                let jsonString = JSON([
                    "command": "subscribe",
                    "channel": Constants.TickerChannel
                ]).rawString()!
                socket.write(string: jsonString)
            }
            
            socket.onText = { [weak self] text in
                if let strongSelf = self, let result = JSON(parseJSON: text).array, result.first?.int == Constants.TickerChannel, let data = result.last?.array, data.count >= 2 {
                    if let productId = data.first?.stringValue, let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: productId) {
                        strongSelf.setPrice(data[1].doubleValue, for: currencyPair)
                        strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                    }
                }
            }
            
            socket.connect()
            self.socket = socket
        }
    }
    
}

