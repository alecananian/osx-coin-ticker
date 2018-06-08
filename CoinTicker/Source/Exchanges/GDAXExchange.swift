//
//  GDAXExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
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
import Starscream
import SwiftyJSON
import PromiseKit

class GDAXExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws-feed.gdax.com")!
        static let ProductListAPIPath = "https://api.gdax.com/products"
        static let TickerAPIPathFormat = "https://api.gdax.com/products/%@/ticker"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .gdax, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json.arrayValue.compactMap { result in
                CurrencyPair(
                    baseCurrency: result["base_currency"].string,
                    quoteCurrency: result["quote_currency"].string,
                    customCode: result["id"].string
                )
            }
        }
    }
    
    override internal func fetch() {
        if isUpdatingInRealTime {
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = socketResponseQueue
            
            let productIds: [String] = selectedCurrencyPairs.map({ $0.customCode })
            socket.onConnect = {
                let json = JSON([
                    "type": "subscribe",
                    "product_ids": productIds,
                    "channels": ["ticker"]
                ])

                if let string = json.rawString() {
                    socket.write(string: string)
                }
            }
            
            socket.onText = { [weak self] text in
                if let strongSelf = self {
                    let json = JSON(parseJSON: text)
                    if json["type"].string == "ticker", let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: json["product_id"].stringValue) {
                        strongSelf.setPrice(json["price"].doubleValue, for: currencyPair)
                        strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                    }
                }
            }
            
            socket.connect()
            self.socket = socket
        } else {
            _ = when(resolved: selectedCurrencyPairs.map({ currencyPair -> Promise<ExchangeAPIResponse> in
                let apiRequestPath = String(format: Constants.TickerAPIPathFormat, currencyPair.customCode)
                return requestAPI(apiRequestPath, for: currencyPair)
            })).map { [weak self] results in
                results.forEach({ result in
                    switch result {
                    case .fulfilled(let value):
                        if let currencyPair = value.representedObject as? CurrencyPair {
                            let price = value.json["price"].doubleValue
                            self?.setPrice(price, for: currencyPair)
                        }
                    default: break
                    }
                })
                
                self?.onFetchComplete()
            }
        }
    }

}
