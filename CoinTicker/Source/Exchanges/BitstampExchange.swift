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
        static let TickerAPIPathFormat = "https://www.bitstamp.net/api/v2/ticker/%@/"
    }
    
    private var sockets: [WebSocket]?
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .bitstamp, delegate: delegate)
    }
    
    override func load() {
        super.load()
        availableCurrencyPairs = [
            CurrencyPair(baseCurrency: .btc, quoteCurrency: .usd),
            CurrencyPair(baseCurrency: .btc, quoteCurrency: .eur),
            CurrencyPair(baseCurrency: .xrp, quoteCurrency: .usd),
            CurrencyPair(baseCurrency: .xrp, quoteCurrency: .eur),
            CurrencyPair(baseCurrency: .xrp, quoteCurrency: .btc)
        ]
        delegate.exchange(self, didUpdateAvailableCurrencyPairs: availableCurrencyPairs)
        fetch()
    }
    
    override func stop() {
        super.stop()
        sockets?.forEach({ $0.disconnect() })
    }
    
    private func productId(forCurrencyPair currencyPair: CurrencyPair) -> String {
        return "\(currencyPair.baseCurrency.code)\(currencyPair.quoteCurrency.code)".lowercased()
    }
    
    override internal func fetch() {
        if TickerConfig.isRealTimeUpdateIntervalSelected {
            if sockets == nil {
                sockets = [WebSocket]()
            }
            
            TickerConfig.selectedCurrencyPairs.forEach({ (currencyPair) in
                let productId = self.productId(forCurrencyPair: currencyPair)
                let socket = WebSocket(url: Constants.WebSocketURL)
                socket.callbackQueue = socketResponseQueue(label: productId)
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
                } as (() -> Void)
                
                socket.onText = { (text: String) in
                    let json = JSON(parseJSON: text)
                    if json["event"] == "trade" {
                        let dataJSON = JSON(parseJSON: json["data"].stringValue)
                        TickerConfig.setPrice(dataJSON["price"].doubleValue, forCurrencyPair: currencyPair)
                    }
                }
                
                socket.connect()
                sockets!.append(socket)
            })
        } else {
            TickerConfig.selectedCurrencyPairs.forEach({ (currencyPair) in
                let apiRequestPath = String(format: Constants.TickerAPIPathFormat, productId(forCurrencyPair: currencyPair))
                apiRequests.append(Alamofire.request(apiRequestPath).response(queue: apiResponseQueue(label: currencyPair.code), responseSerializer: apiResponseSerializer) { (response) in
                    switch response.result {
                    case .success(let value):
                        TickerConfig.setPrice(JSON(value)["last"].doubleValue, forCurrencyPair: currencyPair)
                    case .failure(let error):
                        print("Error retrieving prices for \(currencyPair): \(error)")
                    }
                })
            })
            
            startRequestTimer()
        }
    }

}
