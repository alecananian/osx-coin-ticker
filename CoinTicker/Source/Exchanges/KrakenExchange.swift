//
//  KrakenExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 6/08/17.
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

class KrakenExchange: Exchange {
    
    private struct Constants {
        static let ProductListAPIPath = "https://api.kraken.com/0/public/AssetPairs"
        static let TickerAPIPathFormat = "https://api.kraken.com/0/public/Ticker?pair=%@"
    }
    
    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .kraken, delegate: delegate)
    }
    
    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json["result"].flatMap { data in
                let (productId, result) = data
                guard !productId.contains(".d") else {
                    return nil
                }
                
                return CurrencyPair(
                    baseCurrency: result["base"].string,
                    quoteCurrency: result["quote"].string,
                    customCode: productId
                )
            }
        }
    }
    
    override internal func fetch() {
        let productIds: [String] = selectedCurrencyPairs.flatMap({ $0.customCode })
        let apiPath = String(format: Constants.TickerAPIPathFormat, productIds.joined(separator: ","))
        requestAPI(apiPath).map { [weak self] result in
            for (productId, result) in result.json["result"] {
                if let currencyPair = self?.selectedCurrencyPair(withCustomCode: productId), let price = result["c"].array?.first?.doubleValue {
                    self?.setPrice(price, for: currencyPair)
                }
            }
            
            self?.onFetchComplete()
        }.catch { error in
            print("Error fetching Kraken ticker: \(error)")
        }
    }

}
