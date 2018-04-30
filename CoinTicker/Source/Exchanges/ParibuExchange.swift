//
//  ParibuExchange.swift
//  CoinTicker
//
//  Created by Tolga Y. Özüdoğru on 29.01.2018.
//  Copyright © 2018 Alec Ananian. All rights reserved.
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

class ParibuExchange: Exchange {
    
    private struct Constants {
        static let TickerAPIPath = "https://www.paribu.com/ticker"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .paribu, delegate: delegate)
    }
    
    override func load() {
        setAvailableCurrencyPairs([
            CurrencyPair(baseCurrency: "BTC", quoteCurrency: "TRY", customCode: "BTC_TL")!
        ])
    }
    
    override internal func fetch() {
        let currencyPair = availableCurrencyPairs.first!
        requestAPI(Constants.TickerAPIPath).map { [weak self] result in
            self?.setPrice(result.json[currencyPair.customCode]["last"].doubleValue, for: currencyPair)
            self?.onFetchComplete()
        }.catch { error in
            print("Error fetching Paribu ticker: \(error)")
        }
    }
    
}
