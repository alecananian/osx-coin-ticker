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
import Alamofire
import SocketIO
import SwiftyJSON

class GDAXExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws-feed.gdax.com")!
        static let ProductListAPIPath = "https://api.gdax.com/products"
        static let TickerAPIPathFormat = "https://api.gdax.com/products/%@/ticker"
    }
    
    private var socket: WebSocket?
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .gdax, delegate: delegate)
    }
    
    override func load() {
        super.load()
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue(label: "currencyPairs"), responseSerializer: apiResponseSerializer) { [unowned self] (response) in
            switch response.result {
            case .success(let value):
                if let results = JSON(value).array {
                    results.forEach({ (result) in
                        if let currencyPair = CurrencyPair(baseCurrency: result["base_currency"].string, quoteCurrency: result["quote_currency"].string, customCode: result["id"].string) {
                            self.availableCurrencyPairs.append(currencyPair)
                        }
                    })
                    
                    self.availableCurrencyPairs = self.availableCurrencyPairs.sorted()
                    self.delegate.exchange(self, didUpdateAvailableCurrencyPairs: self.availableCurrencyPairs)
                    self.fetch()
                }
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
            let socket = WebSocket(url: Constants.WebSocketURL)
            socket.callbackQueue = DispatchQueue(label: "cointicker.gdax-socket", qos: .utility, attributes: [.concurrent])
            
            let productIds: [String] = TickerConfig.selectedCurrencyPairs.flatMap({ $0.customCode })
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
            
            socket.onText = { [weak self] (text: String) in
                let json = JSON(parseJSON: text)
                if json["type"].string == "ticker", let currencyPair = self?.availableCurrencyPair(customCode: json["product_id"].stringValue) {
                    TickerConfig.setPrice(json["price"].doubleValue, for: currencyPair)
                }
            }
            
            socket.connect()
            self.socket = socket
        } else {
            TickerConfig.selectedCurrencyPairs.forEach({ (currencyPair) in
                let apiRequestPath = String(format: Constants.TickerAPIPathFormat, currencyPair.customCode)
                apiRequests.append(Alamofire.request(apiRequestPath).response(queue: apiResponseQueue(label: String(describing: currencyPair)), responseSerializer: apiResponseSerializer) { (response) in
                    switch response.result {
                    case .success(let value):
                        TickerConfig.setPrice(JSON(value)["price"].doubleValue, for: currencyPair)
                    case .failure(let error):
                        print("Error retrieving prices for \(currencyPair): \(error)")
                    }
                })
            })
            
            startRequestTimer()
        }
    }

}
