//
//  HitBTCExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/29/18.
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
import PromiseKit

class HitBTCExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://api.hitbtc.com/api/2/ws")!
        static let ProductListAPIPath = "https://api.hitbtc.com/api/2/public/symbol"
        static let FullTickerAPIPath = "https://api.hitbtc.com/api/2/public/ticker"
        static let SingleTickerAPIPathFormat = "https://api.hitbtc.com/api/2/public/ticker/%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .hitbtc, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json.arrayValue.compactMap { result in
                CurrencyPair(
                    baseCurrency: result["baseCurrency"].string,
                    quoteCurrency: result["quoteCurrency"].string,
                    customCode: result["id"].string
                )
            }
        }
    }
    
    override internal func fetch() {
        let apiPath: String
        if selectedCurrencyPairs.count == 1, let currencyPair = selectedCurrencyPairs.first {
            apiPath = String(format: Constants.SingleTickerAPIPathFormat, currencyPair.customCode)
        } else {
            apiPath = Constants.FullTickerAPIPath
        }
        
        requestAPI(apiPath).map { [weak self] result in
            if let strongSelf = self {
                let results = result.json.array ?? [result.json]
                results.forEach({ result in
                    if let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: result["symbol"].stringValue) {
                        strongSelf.setPrice(result["last"].doubleValue, for: currencyPair)
                    }
                })
                
                if strongSelf.isUpdatingInRealTime {
                    strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                } else {
                    strongSelf.onFetchComplete()
                }
            }
        }.catch { error in
            print("Error fetching HitBTC ticker: \(error)")
        }
        
        if isUpdatingInRealTime {
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = socketResponseQueue
            
            socket.onConnect = { [weak self] in
                self?.selectedCurrencyPairs.forEach({ currencyPair in
                    let json = JSON([
                        "method": "subscribeTicker",
                        "params": [
                            "symbol": currencyPair.customCode
                        ]
                    ])
                    
                    if let string = json.rawString() {
                        socket.write(string: string)
                    }
                })
            }
            
            socket.onText = { [weak self] text in
                if let strongSelf = self {
                    let result = JSON(parseJSON: text)
                    if result["method"] == "ticker" {
                        let data = result["params"]
                        if let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: data["symbol"].stringValue) {
                            let price = data["last"].doubleValue
                            strongSelf.setPrice(price, for: currencyPair)
                            strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                        }
                    }
                }
            }
            
            socket.connect()
            self.socket = socket
        }
    }
    
}

