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
        static let TickerAPIPath = "https://api.gdax.com/products/%{productId}/ticker"
    }
    
    private var socket = WebSocket(url: Constants.WebSocketURL)
    private var productId: String {
        return "\(TickerConfig.currentCryptoCurrency.rawValue)-\(TickerConfig.currentCurrency.rawValue)"
    }
    
    override func start() {
        Alamofire.request(Constants.TickerAPIPath.replacingOccurrences(of: "%{productId}", with: productId)).responseJSON { [weak self] response in
            if let tickerData = response.result.value as? [String: Any], let priceString = tickerData["price"] as? String, let price = Double(priceString) {
                self?.delegate.priceDidChange(price: price)
            }
        }
        
        socket.onConnect = { [unowned self] in
            self.socket.write(string: "{\"type\":\"subscribe\",\"product_ids\":[\"\(self.productId)\"]}")
        }
        
        socket.onText = { [weak self] (text: String) in
            if let data = text.data(using: .utf8, allowLossyConversion: false) {
                do {
                    if let json = try JSONSerialization.jsonObject(with: data, options: .mutableContainers) as? [String: Any] {
                        if let type = json["type"] as? String, type == "match", let priceString = json["price"] as? String, let price = Double(priceString) {
                            self?.delegate.priceDidChange(price: price)
                        }
                    }
                } catch {
                    print(error)
                }
            }
        }
        
        socket.connect()
    }
    
    override func stop() {
        socket.disconnect()
    }

}
