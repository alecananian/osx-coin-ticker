//
//  BTCEExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/04/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation
import Alamofire

class BTCEExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://btc-e.com/api/3/info"
        static let TickerAPIPathFormat = "https://btc-e.com/api/3/ticker/%s"
    }
    
    private let apiResponseQueue = DispatchQueue(label: "com.alecananian.cointicker.btce-api", qos: .utility, attributes: [.concurrent])
    private var requestTimer: Timer?
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .btce, delegate: delegate)
    }
    
    override func start() {
        super.start()
        
        var currencyMatrix = CurrencyMatrix()
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let result = response.result.value as? [String: Any], let currencyPairs = result["pairs"] as? [String: Any] {
                for currencyPair in Array(currencyPairs.keys) {
                    let currencyPairArray = currencyPair.split(separator: "_")
                    if let baseCurrencyCode = currencyPairArray.first, let quoteCurrencyCode = currencyPairArray.last, let baseCurrency = Currency.build(fromCode: String(baseCurrencyCode)), baseCurrency.isCrypto, let quoteCurrency = Currency.build(fromCode: String(quoteCurrencyCode)) {
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
        
        requestTimer?.invalidate()
        requestTimer = nil
    }
    
    @objc private func onRequestTimerFired(_ timer: Timer) {
        requestTimer?.invalidate()
        requestTimer = nil
        
        fetchPrice()
    }
    
    @objc private func fetchPrice() {
        let productId = "\(baseCurrency.code)_\(quoteCurrency.code)".lowercased()
        
        apiRequests.append(Alamofire.request(String(format: Constants.TickerAPIPathFormat, productId)).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let tickerData = response.result.value as? [String: Any], let priceData = tickerData[productId] as? [String: Any], let price = priceData["buy"] as? Double {
                self.delegate.exchange(self, didUpdatePrice: price)
                
                DispatchQueue.main.async {
                    self.requestTimer = Timer.scheduledTimer(timeInterval: 10, target: self, selector: #selector(self.onRequestTimerFired(_:)), userInfo: nil, repeats: false)
                }
            }
        })
    }

}
