//
//  BinanceExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 12/23/17.
//  Copyright © 2017 Alec Ananian.
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
import SocketIO
import SwiftyJSON

class BinanceExchange: Exchange {
    
    private struct Constants {
        static let WebSocketPathFormat = "wss://stream.binance.com:9443/stream?streams=%@"
        static let ProductListAPIPath = "https://www.binance.com/api/v1/exchangeInfo"
        static let FullTickerAPIPath = "https://www.binance.com/api/v3/ticker/price"
        static let SingleTickerAPIPathFormat = "https://www.binance.com/api/v3/ticker/price?symbol=%@"
    }
    
    private var socket: WebSocket?
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .binance, delegate: delegate)
    }
    
    override func load() {
        super.load()
        requestAPI(Constants.ProductListAPIPath).then { [weak self] result -> Void in
            let availableCurrencyPairs = result.json["symbols"].arrayValue.flatMap({ result in
                return CurrencyPair(baseCurrency: result["baseAsset"].string, quoteCurrency: result["quoteAsset"].string, customCode: result["symbol"].string)
            })
            self?.onLoaded(availableCurrencyPairs: availableCurrencyPairs)
        }.catch { error in
            print("Error fetching Binance products: \(error)")
        }
    }
    
    override func stop() {
        super.stop()
        socket?.disconnect()
    }
    
    override internal func fetch() {
        if isUpdatingInRealTime {
            let currencyPairCodes: [String] = selectedCurrencyPairs.flatMap({ "\($0.customCode.lowercased())@aggTrade" })
            let socket = WebSocket(url: URL(string: String(format: Constants.WebSocketPathFormat, currencyPairCodes.joined(separator: "/")))!)
            
            socket.onText = { [weak self] text in
                if let strongSelf = self {
                    let result = JSON(parseJSON: text)["data"]
                    if let currencyPair = strongSelf.availableCurrencyPairs.first(where: { $0.customCode == result["s"].stringValue }) {
                        strongSelf.setPrice(result["p"].doubleValue, forCurrencyPair: currencyPair)
                        strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                    }
                }
            }
            
            socket.connect()
            self.socket = socket
        } else {
            var apiPath: String = ""
            if selectedCurrencyPairs.count == 1, let currencyPair = selectedCurrencyPairs.first {
                apiPath = String(format: Constants.SingleTickerAPIPathFormat, currencyPair.customCode)
            } else {
                apiPath = Constants.FullTickerAPIPath
            }
            
            requestAPI(apiPath).then { [weak self] result -> Void in
                let results = result.json.array ?? [result.json]
                results.forEach({ result in
                    if let currencyPair = self?.selectedCurrencyPair(customCode: result["symbol"].stringValue) {
                        self?.setPrice(result["price"].doubleValue, forCurrencyPair: currencyPair)
                    }
                })
                
                self?.onFetchComplete()
            }.catch { error in
                print("Error fetching Binance ticker: \(error)")
            }
        }
    }
    
}
