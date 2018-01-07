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
import Alamofire
import SocketIO
import SwiftyJSON

class BitstampExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws.pusherapp.com/app/de504dc5763aeef9ff52?protocol=7")!
        static let ProductListAPIPath = "https://www.bitstamp.net/api/v2/trading-pairs-info/"
        static let TickerAPIPathFormat = "https://www.bitstamp.net/api/v2/ticker/%@/"
    }
    
    private var sockets: [WebSocket]?
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bitstamp, delegate: delegate)
    }
    
    override func load() {
        super.load()
        requestAPI(Constants.ProductListAPIPath) { [unowned self] (result) in
            let availableCurrencyPairs = result.arrayValue.flatMap({ (result) -> CurrencyPair? in
                let currencyCodes = result["name"].stringValue.split(separator: "/")
                guard currencyCodes.count == 2, let baseCurrency = currencyCodes.first, let quoteCurrency = currencyCodes.last else {
                    return nil
                }
                
                let customCode = result["url_symbol"].string
                guard let currencyPair = CurrencyPair(baseCurrency: String(baseCurrency), quoteCurrency: String(quoteCurrency), customCode: customCode) else {
                    return nil
                }
                
                return (currencyPair.baseCurrency.isCrypto ? currencyPair : nil)
            })
            self.onLoaded(availableCurrencyPairs: availableCurrencyPairs)
        }
    }
    
    override func stop() {
        super.stop()
        sockets?.forEach({ $0.disconnect() })
    }
    
    override internal func fetch() {
        if isUpdatingInRealTime {
            sockets?.forEach({ $0.disconnect() })
            sockets = [WebSocket]()
            
            selectedCurrencyPairs.forEach({ (currencyPair) in
                let productId = currencyPair.customCode
                let socket = WebSocket(url: Constants.WebSocketURL)
                socket.callbackQueue = socketResponseQueue
                socket.onConnect = {
                    var channelName = "live_trades"
                    if currencyPair.baseCurrency != .btc || currencyPair.quoteCurrency != .usd {
                        channelName += "_\(productId)"
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
                }
                
                socket.onText = { [weak self] (text: String) in
                    if let strongSelf = self {
                        var result = JSON(parseJSON: text)
                        if result["event"] == "trade" {
                            result = JSON(parseJSON: result["data"].stringValue)
                            strongSelf.setPrice(result["price"].doubleValue, forCurrencyPair: currencyPair)
                            strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                        }
                    }
                }
                
                socket.connect()
                sockets!.append(socket)
            })
        } else {
            selectedCurrencyPairs.forEach({ (currencyPair) in
                let productId = currencyPair.customCode
                let apiRequestPath = String(format: Constants.TickerAPIPathFormat, productId)
                requestAPI(apiRequestPath) { [weak self] (result) in
                    self?.setPrice(result["last"].doubleValue, forCurrencyPair: currencyPair)
                    self?.onFetchComplete()
                }
            })
        }
    }

}
