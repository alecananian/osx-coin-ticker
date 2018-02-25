//
//  CoinoneExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/7/18.
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
import PromiseKit

class CoinoneExchange: Exchange {
    
    private struct Constants {
        static let TickerAPIPathFormat = "https://api.coinone.co.kr/ticker/?currency=%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .coinone, delegate: delegate)
    }
    
    override func load() {
        super.load()
        onLoaded(availableCurrencyPairs: [
            CurrencyPair(baseCurrency: "BTC", quoteCurrency: "KRW", customCode: "btc")!,
            CurrencyPair(baseCurrency: "BCH", quoteCurrency: "KRW", customCode: "bch")!,
            CurrencyPair(baseCurrency: "BTG", quoteCurrency: "KRW", customCode: "btg")!,
            CurrencyPair(baseCurrency: "ETH", quoteCurrency: "KRW", customCode: "eth")!,
            CurrencyPair(baseCurrency: "ETC", quoteCurrency: "KRW", customCode: "etc")!,
            CurrencyPair(baseCurrency: "IOTA", quoteCurrency: "KRW", customCode: "iota")!,
            CurrencyPair(baseCurrency: "LTC", quoteCurrency: "KRW", customCode: "ltc")!,
            CurrencyPair(baseCurrency: "QTUM", quoteCurrency: "KRW", customCode: "qtum")!,
            CurrencyPair(baseCurrency: "XRP", quoteCurrency: "KRW", customCode: "xrp")!
        ])
    }
    
    override internal func fetch() {
        when(resolved: selectedCurrencyPairs.map({ currencyPair -> Promise<ExchangeAPIResponse> in
            let apiRequestPath = String(format: Constants.TickerAPIPathFormat, currencyPair.customCode)
            return requestAPI(apiRequestPath, for: currencyPair)
        })).then { [weak self] results -> Void in
            results.forEach({ result in
                switch result {
                case .fulfilled(let value):
                    if let currencyPair = value.representedObject as? CurrencyPair {
                        let price = value.json["last"].doubleValue
                        self?.setPrice(price, for: currencyPair)
                    }
                default: break
                }
            })
            
            self?.onFetchComplete()
        }.always {}
    }
    
}
