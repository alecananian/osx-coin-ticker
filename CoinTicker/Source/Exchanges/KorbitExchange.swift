//
//  KorbitExchange.swift
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

class KorbitExchange: Exchange {
    
    private struct Constants {
        static let TickerAPIPathFormat = "https://api.korbit.co.kr/v1/ticker?currency_pair=%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .korbit, delegate: delegate)
    }
    
    override func load() {
        super.load()
        onLoaded(availableCurrencyPairs: [
            CurrencyPair(baseCurrency: .btc, quoteCurrency: .krw, customCode: "btc_krw"),
            CurrencyPair(baseCurrency: .eth, quoteCurrency: .krw, customCode: "eth_krw"),
            CurrencyPair(baseCurrency: .etc, quoteCurrency: .krw, customCode: "etc_krw"),
            CurrencyPair(baseCurrency: .xrp, quoteCurrency: .krw, customCode: "xrp_krw")
        ])
    }
    
    override internal func fetch() {
        selectedCurrencyPairs.forEach({ (currencyPair) in
            let productId = currencyPair.customCode
            let apiRequestPath = String(format: Constants.TickerAPIPathFormat, productId)
            requestAPI(apiRequestPath) { [weak self] (result) in
                self?.setPrice(result["last"].doubleValue, forCurrencyPair: currencyPair)
                self?.onFetchComplete()
            }
        })
    }

}
