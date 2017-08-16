//
//  KrakenExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/08/17.
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

class KrakenExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://api.kraken.com/0/public/AssetPairs"
        static let TickerAPIPathFormat = "https://api.kraken.com/0/public/Ticker?pair=%@"
    }
    
    private let apiResponseQueue = DispatchQueue(label: "cointicker.kraken-api", qos: .utility, attributes: [.concurrent])
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .kraken, delegate: delegate)
    }
    
    override func start() {
        super.start()
        
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let currencyPairs = (response.result.value as? JSONContainer)?["result"] as? JSONContainer {
                var currencyMatrix = CurrencyMatrix()
                for (currencyPairString, currencyPairData) in currencyPairs {
                    if !currencyPairString.contains(".d"), let currencyPairData = currencyPairData as? JSONContainer {
                        if let baseCurrencyCode = currencyPairData["base"] as? String, let baseCurrency = Currency.build(fromCode: baseCurrencyCode), let quoteCurrencyCode = currencyPairData["quote"] as? String, let quoteCurrency = Currency.build(fromCode: quoteCurrencyCode) {
                            currencyMatrix[baseCurrency, default: [Currency]()].append(quoteCurrency)
                        }
                    }
                }
                
                self.currencyMatrix = currencyMatrix
                self.delegate.exchange(self, didLoadCurrencyMatrix: currencyMatrix)
                
                self.fetchPrice()
            }
        })
    }
    
    override internal func fetchPrice() {
        let productId = "\(baseCurrency.code)\(quoteCurrency.code)".uppercased()
        
        apiRequests.append(Alamofire.request(String(format: Constants.TickerAPIPathFormat, productId)).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let result = (response.result.value as? JSONContainer)?["result"] as? JSONContainer, let currencyPairCode = result.keys.first, let currencyPairData = result[currencyPairCode] as? JSONContainer {
                if let priceString = (currencyPairData["p"] as? [String])?.last, let price = Double(priceString) {
                    self.delegate.exchange(self, didUpdatePrice: price)
                }
            }
            
            self.startRequestTimer()
        })
    }

}
