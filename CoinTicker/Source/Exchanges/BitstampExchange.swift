//
//  BitstampExchange.swift
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

class BitstampExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws.pusherapp.com/app/de504dc5763aeef9ff52?protocol=7")!
        static let ProductListAPIPath = "https://www.bitstamp.net/api/v2/trading-pairs-info/"
        static let TickerAPIPathFormat = "https://www.bitstamp.net/api/v2/ticker/%@/"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bitstamp, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json.arrayValue.compactMap { result in
                let currencyCodes = result["name"].stringValue.split(separator: "/")
                guard currencyCodes.count == 2, let baseCurrency = currencyCodes.first, let quoteCurrency = currencyCodes.last else {
                    return nil
                }
                
                let customCode = result["url_symbol"].string
                guard let currencyPair = CurrencyPair(baseCurrency: String(baseCurrency), quoteCurrency: String(quoteCurrency), customCode: customCode) else {
                    return nil
                }
                
                return (currencyPair.baseCurrency.isPhysical ? nil : currencyPair)
            }
        }
    }
    
    override internal func fetch() {
        if isUpdatingInRealTime {
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = socketResponseQueue
            
            socket.onConnect = { [weak self] in
                self?.selectedCurrencyPairs.forEach({ currencyPair in
                    var channelName = "live_trades"
                    if !currencyPair.baseCurrency.isBitcoin || currencyPair.quoteCurrency.code != "USD" {
                        channelName += "_\(currencyPair.customCode)"
                    }
                    
                    let json = JSON([
                        "event": "pusher:subscribe",
                        "data": [
                            "channel": channelName
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
                    if result["event"] == "trade" {
                        let productId = result["channel"].stringValue.replacingOccurrences(of: "live_trades_", with: "")
                        if let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: (productId == "live_trades" ? "btcusd" : productId)) {
                            let data = JSON(parseJSON: result["data"].stringValue)
                            strongSelf.setPrice(data["price"].doubleValue, for: currencyPair)
                            strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                        }
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
                            let price = value.json["last"].doubleValue
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
