//
//  BTCEExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/04/17.
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

class BTCEExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://btc-e.com/api/3/info"
        static let TickerAPIPathFormat = "https://btc-e.com/api/3/ticker/%@"
    }
    
    private let apiResponseQueue = DispatchQueue(label: "com.alecananian.cointicker.btce-api", qos: .utility, attributes: [.concurrent])
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .btce, delegate: delegate)
    }
    
    override func start() {
        super.start()
        
        var currencyMatrix = CurrencyMatrix()
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let currencyPairs = (response.result.value as? JSONContainer)?["pairs"] as? JSONContainer {
                for (currencyPair, _) in currencyPairs {
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
    
    override internal func fetchPrice() {
        let productId = "\(baseCurrency.code)_\(quoteCurrency.code)".lowercased()
        
        apiRequests.append(Alamofire.request(String(format: Constants.TickerAPIPathFormat, productId)).response(queue: apiResponseQueue, responseSerializer: DataRequest.jsonResponseSerializer()) { [unowned self] (response) in
            if let price = ((response.result.value as? JSONContainer)?[productId] as? JSONContainer)?["buy"] as? Double {
                self.delegate.exchange(self, didUpdatePrice: price)
            }
            
            self.startRequestTimer()
        })
    }

}
