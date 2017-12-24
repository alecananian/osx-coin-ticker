//
//  CoincheckExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/24/17.
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

class CoincheckExchange: Exchange {
    
    private struct Constants {
        static let TickerAPIPath = "https://coincheck.com/api/ticker"
    }
    
    init(delegate: ExchangeDelegate) {
        super.init(site: .coincheck, delegate: delegate)
    }
    
    override func load() {
        super.load()
        availableCurrencyPairs = [CurrencyPair(baseCurrency: .btc, quoteCurrency: .jpy)]
        delegate.exchange(self, didUpdateAvailableCurrencyPairs: availableCurrencyPairs)
        fetch()
    }
    
    override internal func fetch() {
        let currencyPair = availableCurrencyPairs.first!
        apiRequests.append(Alamofire.request(Constants.TickerAPIPath).response(queue: apiResponseQueue(label: currencyPair.customCode), responseSerializer: apiResponseSerializer) { [weak self] (response) in
            switch response.result {
            case .success(let value):
                TickerConfig.setPrice(JSON(value)["last"].doubleValue, for: currencyPair)
            case .failure(let error):
                print("Error retrieving prices for \(currencyPair): \(error)")
            }
            
            self?.startRequestTimer()
        })
    }

}
