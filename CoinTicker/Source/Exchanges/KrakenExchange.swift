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
import SwiftyJSON

class KrakenExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://api.kraken.com/0/public/AssetPairs"
        static let TickerAPIPathFormat = "https://api.kraken.com/0/public/Ticker?pair=%@"
    }
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .kraken, delegate: delegate)
    }
    
    override func load() {
        super.load()
        apiRequests.append(Alamofire.request(Constants.ProductListAPIPath).response(queue: apiResponseQueue(label: "currencyPairs"), responseSerializer: apiResponseSerializer) { [unowned self] (response) in
            switch response.result {
            case .success(let value):
                for (productId, result) in JSON(value)["result"] {
                    if !productId.contains(".d"), let currencyPair = CurrencyPair(baseCurrency: result["base"].string, quoteCurrency: result["quote"].string) {
                        self.availableCurrencyPairs.append(currencyPair)
                    }
                }
                
                self.availableCurrencyPairs = self.availableCurrencyPairs.sorted()
                self.delegate.exchange(self, didUpdateAvailableCurrencyPairs: self.availableCurrencyPairs)
                self.fetch()
            case .failure(let error):
                print("Error retrieving currency pairs: \(error)")
            }
        })
    }
    
    override internal func fetch() {
        TickerConfig.selectedCurrencyPairs.forEach({ (currencyPair) in
            let productId = "\(currencyPair.baseCurrency.code)\(currencyPair.quoteCurrency.code)".uppercased()
            let apiRequestPath = String(format: Constants.TickerAPIPathFormat, productId)
            apiRequests.append(Alamofire.request(apiRequestPath).response(queue: apiResponseQueue(label: currencyPair.code), responseSerializer: apiResponseSerializer) { (response) in
                switch response.result {
                case .success(let value):
                    TickerConfig.setPrice((JSON(value)["result"].first?.1["c"].first?.1.doubleValue ?? 0), forCurrencyPair: currencyPair)
                case .failure(let error):
                    print("Error retrieving prices for \(currencyPair): \(error)")
                }
            })
        })
        
        startRequestTimer()
    }

}
