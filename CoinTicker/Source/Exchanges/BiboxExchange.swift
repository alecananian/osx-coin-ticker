//
//  BiboxExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/25/18.
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

class BiboxExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://api.bibox.com/v1/mdata?cmd=pairList"
        static let TickerAPIPathFormat = "https://api.bibox.com/v1/mdata?cmd=ticker&pair=%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bibox, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json["result"].arrayValue.compactMap { result in
                let customCode = result["pair"].stringValue
                let currencyCodes = customCode.split(separator: "_")
                guard currencyCodes.count == 2, let baseCurrency = currencyCodes.first, let quoteCurrency = currencyCodes.last else {
                    return nil
                }
                
                return CurrencyPair(
                    baseCurrency: String(baseCurrency),
                    quoteCurrency: String(quoteCurrency),
                    customCode: customCode
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
                        let price = value.json["result"]["last"].doubleValue
                        self?.setPrice(price, for: currencyPair)
                    }
                default: break
                }
            })
            
            self?.onFetchComplete()
        }
    }
    
}
