//
//  BTCTurkExchange.swift
//  CoinTicker
//
//  Created by Tolga Y. Özüdoğru on 6/8/18.
//  Copyright © 2018 Alec Ananian.
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
import SwiftyJSON

class BTCTurkExchange: Exchange {
    
    private struct Constants {
        static let FullTickerAPIPath = "https://api.btcturk.com/api/v2/ticker"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .btcturk, delegate: delegate)
    }
    
    override func load() {
        setAvailableCurrencyPairs([
            CurrencyPair(baseCurrency: "BTC", quoteCurrency: "TRY", customCode: "BTCTRY")!,
            CurrencyPair(baseCurrency: "ETH", quoteCurrency: "TRY", customCode: "ETHTRY")!,
            CurrencyPair(baseCurrency: "LTC", quoteCurrency: "TRY", customCode: "LTCTRY")!,
            CurrencyPair(baseCurrency: "XRP", quoteCurrency: "TRY", customCode: "XRPTRY")!
        ])
    }
    
    override internal func fetch() {
        requestAPI(Constants.FullTickerAPIPath).map { [weak self] result in
            result.json["data"].arrayValue.forEach({ data in
                let (productId, price) = (data["pair"].stringValue, data["last"].doubleValue)
                
                if let currencyPair = self?.selectedCurrencyPair(withCustomCode: productId) {
                    self?.setPrice(price, for: currencyPair)
                }
            })
            
            self?.onFetchComplete()
        }.catch { error in
            print("Error fetching BTCTurk ticker: \(error)")
        }
    }
    
}
