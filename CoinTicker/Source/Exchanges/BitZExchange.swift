//
//  BitZExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 2/18/18.
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

class BitZExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://www.bit-z.com/api_v1/tickerall"
        static let FullTickerAPIPath = "https://www.bit-z.com/api_v1/tickerall"
        static let SingleTickerAPIPathFormat = "https://www.bit-z.com/api_v1/ticker?coin=%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bitz, delegate: delegate)
    }
    
    override func load() {
        super.load()
        super.load(from: Constants.ProductListAPIPath) {
            $0.json["data"].dictionaryValue.keys.flatMap { customCode in
                let customCodeParts = customCode.split(separator: "_")
                guard let baseCurrency = customCodeParts.first, let quoteCurrency = customCodeParts.last else {
                    return nil
                }
                
                return CurrencyPair(baseCurrency: String(baseCurrency), quoteCurrency: String(quoteCurrency), customCode: customCode)
            }
        }
    }
    
    override internal func fetch() {
        let apiPath: String
        if selectedCurrencyPairs.count == 1, let currencyPair = selectedCurrencyPairs.first {
            apiPath = String(format: Constants.SingleTickerAPIPathFormat, currencyPair.customCode)
        } else {
            apiPath = Constants.FullTickerAPIPath
        }
        
        requestAPI(apiPath).then { [weak self] result -> Void in
            if let strongSelf = self {
                let data = result.json["data"]
                if strongSelf.selectedCurrencyPairs.count == 1, let currencyPair = strongSelf.selectedCurrencyPairs.first {
                    strongSelf.setPrice(data["last"].doubleValue, for: currencyPair)
                } else {
                    data.forEach({ (customCode, info) in
                        if let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: customCode) {
                            strongSelf.setPrice(info["last"].doubleValue, for: currencyPair)
                        }
                    })
                }
                
                strongSelf.onFetchComplete()
            }
        }.catch { error in
            print("Error fetching Bit-Z ticker: \(error)")
        }
    }
    
}

