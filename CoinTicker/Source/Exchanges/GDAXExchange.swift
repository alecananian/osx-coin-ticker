//
//  GDAXExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation
import Alamofire
import Starscream

class GDAXExchange: Exchange {
    
    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws-feed.gdax.com")!
        static let ProductListAPIPath = "https://api.gdax.com/products"
        static let TickerAPIPathFormat = "https://api.gdax.com/products/%@/ticker"
    }
    
    private let webSocketQueue = DispatchQueue(label: "com.alecananian.cointicker.gdax-socket", qos: .utility, attributes: [.concurrent])
    private let apiResponseQueue = DispatchQueue(label: "com.alecananian.cointicker.gdax-api", qos: .utility, attributes: [.concurrent])
    private var socket = WebSocket(url: Constants.WebSocketURL)
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .gdax, delegate: delegate)
        
        socket.callbackQueue = webSocketQueue
    }
    
    override func start() {
        super.start()
        
        var currencyMatrix = CurrencyMatrix()
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let currencyPairs = response.result.value as? [[String: Any]] {
                for currencyPair in currencyPairs {
                    if let baseCurrencyCode = currencyPair["base_currency"] as? String, let quoteCurrencyCode = currencyPair["quote_currency"] as? String, let baseCurrency = Currency.build(fromCode: baseCurrencyCode), baseCurrency.isCrypto, let quoteCurrency = Currency.build(fromCode: quoteCurrencyCode) {
                        if currencyMatrix[baseCurrency] == nil {
                            currencyMatrix[baseCurrency] = [Currency]()
                        }
                        
                        currencyMatrix[baseCurrency]!.append(quoteCurrency)
                    }
                }
                
                self.currencyMatrix = currencyMatrix
                self.delegate.exchange(self, didLoadCurrencyMatrix: currencyMatrix)
                
                self.fetchPrice()
            }
        })
    }
    
    override func stop() {
        super.stop()
        
        socket.disconnect()
    }
    
    private func fetchPrice() {
        let productId = "\(baseCurrency.code)-\(quoteCurrency.code)"
        
        apiRequests.append(Alamofire.request(String(format: Constants.TickerAPIPathFormat, productId)).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let tickerData = response.result.value as? [String: Any], let priceString = tickerData["price"] as? String, let price = Double(priceString) {
                self.delegate.exchange(self, didUpdatePrice: price)
            }
        })
        
        socket.onConnect = { [unowned self] in
            let eventParams: [String: Any] = [
                "type": "subscribe",
                "product_ids": [productId]
            ]
            
            do {
                let eventJSON = try JSONSerialization.data(withJSONObject: eventParams, options: [])
                if let eventString = String(data: eventJSON, encoding: .utf8) {
                    self.socket.write(string: eventString)
                }
            } catch {
                print(error)
            }
        } as (() -> Void)
        
        socket.onText = { [unowned self] (text: String) in
            if let data = text.data(using: .utf8, allowLossyConversion: false) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                        if let type = json["type"] as? String, type == "match", let priceString = json["price"] as? String, let price = Double(priceString) {
                            self.delegate.exchange(self, didUpdatePrice: price)
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
        
        socket.connect()
    }

}
