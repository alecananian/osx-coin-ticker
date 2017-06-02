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
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .gdax, delegate: delegate, currencyMatrix: [
            .bitcoin: [.usd, .eur, .gbp],
            .ethereum: [.usd, .eur],
            .litecoin: [.usd, .eur]
        ])
    }
    
    override func start() {
        let productId = "\(baseCurrency.code)-\(displayCurrency.rawValue)"
        
        Alamofire.request(Constants.TickerAPIPath.replacingOccurrences(of: "%{productId}", with: productId)).responseJSON { [unowned self] response in
            if let tickerData = response.result.value as? [String: Any], let priceString = tickerData["price"] as? String, let price = Double(priceString) {
                self.delegate.exchange(self, didUpdatePrice: price)
            }
        }
        
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
        }
        
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
    
    override func stop() {
        socket.disconnect()
    }

}
