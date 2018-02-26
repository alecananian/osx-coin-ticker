//
//  BithumbExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/14/18.
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

class BithumbExchange: Exchange {
    
    private struct Constants {
        static let FullTickerAPIPath = "https://api.bithumb.com/public/ticker/ALL"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bithumb, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.FullTickerAPIPath) {
            $0.json["data"].flatMap { data in
                CurrencyPair(
                    baseCurrency: data.0,
                    quoteCurrency: "KRW",
                    customCode: data.0
                )
            }
        }
    }
    
    override internal func fetch() {
        requestAPI(Constants.FullTickerAPIPath).then { [weak self] result -> Void in
            result.json["data"].forEach({ data in
                let (productId, info) = data
                if let currencyPair = self?.selectedCurrencyPair(withCustomCode: productId) {
                    self?.setPrice(info["closing_price"].doubleValue, for: currencyPair)
                }
            })
            
            self?.onFetchComplete()
        }.catch { error in
            print("Error fetching Bithumb ticker: \(error)")
        }
    }
    
}
