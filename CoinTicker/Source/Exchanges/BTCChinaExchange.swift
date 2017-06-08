//
//  BTCChinaExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/07/17.
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

class BTCChinaExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "https://websocket.btcchina.com/")!
        static let TickerAPIPathFormat = "https://data.btcchina.com/data/ticker?market=%@"
    }
    
    private let webSocketQueue = DispatchQueue(label: "com.alecananian.cointicker.btcchina-socket", qos: .utility, attributes: [.concurrent])
    private let apiResponseQueue = DispatchQueue(label: "com.alecananian.cointicker.btcchina-api", qos: .utility, attributes: [.concurrent])
    private var socket = SocketIOClient(socketURL: Constants.WebSocketURL)
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .btcChina, delegate: delegate)
    }
    
    override func start() {
        super.start()
        
        currencyMatrix = [
            .btc: [.cny],
            .ltc: [.cny, .btc]
        ]
        delegate.exchange(self, didLoadCurrencyMatrix: currencyMatrix!)
        
        fetchPrice()
    }
    
    override func stop() {
        super.stop()
        
        socket.disconnect()
    }
    
    private func fetchPrice() {
        let parsePrice: (_ json: JSONContainer) -> Void = { [unowned self] (json) in
            if let tickerJSON = json["ticker"] as? JSONContainer {
                if let priceString = tickerJSON["last"] as? String, let price = Double(priceString) {
                    self.delegate.exchange(self, didUpdatePrice: price)
                } else if let price = tickerJSON["last"] as? Double {
                    self.delegate.exchange(self, didUpdatePrice: price)
                }
            }
        }
        
        let apiProductId = "\(baseCurrency.code)\(quoteCurrency.code)".lowercased()
        apiRequests.append(Alamofire.request(String(format: Constants.TickerAPIPathFormat, apiProductId)).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { (response) in
            if let responseJSON = response.result.value as? JSONContainer {
                parsePrice(responseJSON)
            }
        })
        
        let socketProductId = "\(quoteCurrency.code)\(baseCurrency.code)".lowercased()
        socket.on(clientEvent: .connect) { [unowned self] (data, ack) in
            self.socket.emit("subscribe", with: ["marketdata_\(socketProductId)"])
        }
        
        socket.on("ticker") { (data, _) in
            if let responseJSON = data.first as? JSONContainer {
                parsePrice(responseJSON)
            }
        }
        
        socket.connect()
    }
    
}

