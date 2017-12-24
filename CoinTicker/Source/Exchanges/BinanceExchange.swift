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
import Alamofire
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
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .bitstamp, delegate: delegate)
    }
    
    override func load() {
        super.load()
        
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue(label: "currencyPairs"), responseSerializer: apiResponseSerializer) { [unowned self] (response) in
            switch response.result {
            case .success(let value):
                JSON(value)["symbols"].array?.forEach({ (result) in
                    if let currencyPair = CurrencyPair(baseCurrency: result["baseAsset"].string, quoteCurrency: result["quoteAsset"].string, customCode: result["symbol"].string) {
                        self.availableCurrencyPairs.append(currencyPair)
                    }
                })
                
                self.availableCurrencyPairs = self.availableCurrencyPairs.sorted()
                self.delegate.exchange(self, didUpdateAvailableCurrencyPairs: self.availableCurrencyPairs)
                self.fetch()
            case .failure(let error):
                print("Error retrieving currency pairs: \(error)")
            }
        })
    }
    
    override func stop() {
        super.stop()
        socket?.disconnect()
    }
    
    override internal func fetch() {
        if TickerConfig.isRealTimeUpdateIntervalSelected {
            let currencyPairCodes: [String] = TickerConfig.selectedCurrencyPairs.flatMap({ "\($0.customCode.lowercased())@aggTrade" })
            let socket = WebSocket(url: URL(string: String(format: Constants.WebSocketPathFormat, currencyPairCodes.joined(separator: "/")))!)
            
            socket.onText = { [weak self] (text: String) in
                let json = JSON(parseJSON: text)["data"]
                if let currencyPair = self?.availableCurrencyPairs.first(where: { $0.customCode == json["s"].stringValue }) {
                    TickerConfig.setPrice(json["p"].doubleValue, for: currencyPair)
                }
            }
            
            socket.connect()
            self.socket = socket
        } else {
            var apiPath: String = ""
            if TickerConfig.selectedCurrencyPairs.count == 1, let currencyPair = TickerConfig.selectedCurrencyPairs.first {
                apiPath = String(format: Constants.SingleTickerAPIPathFormat, currencyPair.customCode)
            } else {
                apiPath = Constants.FullTickerAPIPath
            }
            
            apiRequests.append(Alamofire.request(apiPath).response(queue: apiResponseQueue(label: "ticker"), responseSerializer: apiResponseSerializer) { [weak self] (response) in
                switch response.result {
                case .success(let value):
                    let json = JSON(value)
                    let results = json.array ?? [json]
                    results.forEach({ (result) in
                        if let currencyPair = self?.availableCurrencyPairs.first(where: { $0.customCode == result["symbol"].stringValue }) {
                            TickerConfig.setPrice(result["price"].doubleValue, for: currencyPair)
                        }
                    })
                case .failure(let error):
                    print("Error retrieving prices: \(error)")
                }
            })
        }
    }
    
}
