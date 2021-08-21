//
//  UPbitExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/25/17.
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
import SwiftyJSON

class UPbitExchange: Exchange {

    private struct Constants {
        static let ProductListAPIPath = "https://api.upbit.com/v1/market/all"
        static let TickerAPIPathFormat = "https://api.upbit.com/v1/ticker?markets=%@"
    }

    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .upbit, delegate: delegate)
    }

    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json.arrayValue.compactMap { data in
                let productId = data["market"].stringValue
                let customCodeParts = productId.split(separator: "-")
                guard let quoteCurrency = customCodeParts.first, let baseCurrency = customCodeParts.last else {
                    return nil
                }

                return CurrencyPair(
                    baseCurrency: String(baseCurrency),
                    quoteCurrency: String(quoteCurrency),
                    customCode: productId
                )
            }
        }
    }

    override internal func fetch() {
        let productIds: [String] = selectedCurrencyPairs.map({ $0.customCode })
        let apiPath = String(format: Constants.TickerAPIPathFormat, productIds.joined(separator: ","))
        requestAPI(apiPath).map { [weak self] result in
            result.json.arrayValue.forEach({ data in
                if let currencyPair = self?.selectedCurrencyPair(withCustomCode: data["market"].stringValue) {
                    self?.setPrice(data["trade_price"].doubleValue, for: currencyPair)
                }
            })

            self?.onFetchComplete()
        }.catch { error in
            print("Error fetching UPbit ticker: \(error)")
        }
    }

}
