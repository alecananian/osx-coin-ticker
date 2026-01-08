//
//  PoloniexExchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 1/9/18.
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
import Starscream
import SwiftyJSON
import PromiseKit

class PoloniexExchange: Exchange {

    private struct Constants {
        static let WebSocketURL = URL(string: "wss://ws.poloniex.com/ws/public")!
        static let ProductListAPIPath = "https://api.poloniex.com/markets"
        static let TickerAPIPathFormat = "https://api.poloniex.com/markets/%@/price"
    }

    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .poloniex, delegate: delegate)
    }

    override func load() {
        super.load(from: Constants.ProductListAPIPath) {
            $0.json.arrayValue.compactMap { data in
                CurrencyPair(
                    baseCurrency: data["baseCurrencyName"].string,
                    quoteCurrency: data["quoteCurrencyName"].string,
                    customCode: "\(data["baseCurrencyName"])_\(data["quoteCurrencyName"])"
                )
            }
        }
    }

    override internal func fetch() {
        if isUpdatingInRealTime {
            let socket = WebSocket(request: URLRequest(url: Constants.WebSocketURL))
            socket.callbackQueue = socketResponseQueue

            let symbols: [String] = selectedCurrencyPairs.map({ $0.customCode })
            socket.onEvent = { [weak self] event in
                switch event {
                case .connected:
                    let json = JSON([
                        "event": "subscribe",
                        "channel": ["ticker"],
                        "symbols": symbols
                    ])

                    if let string = json.rawString() {
                        socket.write(string: string)
                    }

                case .text(let text):
                    if let strongSelf = self {
                        let json = JSON(parseJSON: text)
                        if json["channel"].string == "ticker", let data = json["data"].array?.last, let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: data["symbol"].stringValue) {
                            strongSelf.setPrice(data["markPrice"].doubleValue, for: currencyPair)
                            strongSelf.delegate?.exchangeDidUpdatePrices(strongSelf)
                        }
                    }

                default:
                    break
                }
            }

            socket.connect()
            self.socket = socket
        } else {
            _ = when(resolved: selectedCurrencyPairs.map({ currencyPair -> Promise<ExchangeAPIResponse> in
                let apiRequestPath = String(format: Constants.TickerAPIPathFormat, currencyPair.customCode)
                return requestAPI(apiRequestPath, for: currencyPair)
            })).map { [weak self] results in
                results.forEach({ result in
                    switch result {
                    case .fulfilled(let value):
                        if let currencyPair = value.representedObject as? CurrencyPair {
                            let price = value.json["price"].doubleValue
                            self?.setPrice(price, for: currencyPair)
                        }
                    default: break
                    }
                })

                self?.onFetchComplete()
            }
        }
    }

}
