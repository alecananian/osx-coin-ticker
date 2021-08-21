//
//  KuCoinExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 11/08/20.
//  Copyright © 2020 Alec Ananian.
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

class KuCoinExchange: Exchange {

    private struct Constants {
        static let ProductListAPIPath = "https://api.kucoin.com/api/v1/symbols"
        static let TickerAPIPathFormat = "https://api.kucoin.com/api/v1/market/orderbook/level1?symbol=%@"
    }

    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .kucoin, delegate: delegate)
    }

    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json["data"].arrayValue.compactMap { data in
                return CurrencyPair(
                    baseCurrency: data["baseCurrency"].string,
                    quoteCurrency: data["quoteCurrency"].string,
                    customCode: data["symbol"].string
                )
            }
        }
    }

    override internal func fetch() {
        _ = when(resolved: selectedCurrencyPairs.map({ currencyPair -> Promise<ExchangeAPIResponse> in
            let apiRequestPath = String(format: Constants.TickerAPIPathFormat, currencyPair.customCode)
            return requestAPI(apiRequestPath, for: currencyPair)
        })).map { [weak self] results in
            results.forEach({ result in
                switch result {
                case .fulfilled(let value):
                    if let currencyPair = value.representedObject as? CurrencyPair {
                        let price = value.json["data"]["price"].doubleValue
                        self?.setPrice(price, for: currencyPair)
                    }
                default: break
                }
            })

            self?.onFetchComplete()
        }
    }

}
