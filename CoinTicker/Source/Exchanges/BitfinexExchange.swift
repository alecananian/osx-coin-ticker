//
//  BitfinexExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/7/18.
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

class BitfinexExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://api.bitfinex.com/ws/2")!
        static let ProductListAPIPath = "https://api.bitfinex.com/v1/symbols"
        static let TickerAPIPathFormat = "https://api.bitfinex.com/v2/tickers?symbols=%@"
    }
    
    private var socket: WebSocket?
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bitfinex, delegate: delegate)
    }
    
    override func load() {
        super.load()
        requestAPI(Constants.ProductListAPIPath).then { [weak self] result -> Void in
            let availableCurrencyPairs = result.json.arrayValue.flatMap({ result -> CurrencyPair? in
                let pairString = result.stringValue
                if pairString.count == 6 {
                    let baseCurrency = String(pairString.prefix(3))
                    let quoteCurrency = String(pairString.suffix(3))
                    let customCode = "t\(pairString.uppercased())"
                    return CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency, customCode: customCode)
                }
                
                return nil
            })
            self?.onLoaded(availableCurrencyPairs: availableCurrencyPairs)
            }.catch { error in
                print("Error fetching Bitfinex products: \(error)")
        }
    }
    
    override func stop() {
        super.stop()
        socket?.disconnect()
    }
    
    override internal func fetch() {
        if isUpdatingInRealTime {
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = socketResponseQueue
            
            var channelIds =  [String: Int]()
            selectedCurrencyPairs.forEach({ channelIds[$0.customCode] = 0 })
            socket.onConnect = {
                channelIds.keys.forEach({ productId in
                    let json = JSON([
                        "event": "subscribe",
                        "channel": "ticker",
                        "symbol": productId
                    ])
                    
                    if let string = json.rawString() {
                        socket.write(string: string)
                    }
                })
            }
            
            socket.onText = { [weak self] text in
                if let strongSelf = self {
                    let json = JSON(parseJSON: text)
                    if json["event"] == "subscribed" {
                        if let productId = json["symbol"].string {
                            channelIds[productId] = json["chanId"].intValue
                        }
                    } else if let data = json.array,
                        let channelId = data.first?.int,
                        let info = data.last?.array, info.count > 6,
                        let productId = channelIds.first(where: { $0.value == channelId })?.0,
                        let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: productId) {
                        let price = info[6].doubleValue
                        strongSelf.setPrice(price, for: currencyPair)
                        strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                    }
                }
            }
            
            socket.connect()
            self.socket = socket
        } else {
            let productIds: [String] = selectedCurrencyPairs.flatMap({ $0.customCode })
            let apiPath = String(format: Constants.TickerAPIPathFormat, productIds.joined(separator: ","))
            requestAPI(apiPath).then { [weak self] result -> Void in
                result.json.arrayValue.forEach({ result in
                    let data = result.arrayValue
                    if data.count > 7, let currencyPair = self?.selectedCurrencyPair(withCustomCode: data.first!.stringValue) {
                        let price = data[7].doubleValue
                        self?.setPrice(price, for: currencyPair)
                    }
                })
                
                self?.onFetchComplete()
            }.catch { error in
                print("Error fetching Bitfinex ticker: \(error)")
            }
        }
    }
    
}

