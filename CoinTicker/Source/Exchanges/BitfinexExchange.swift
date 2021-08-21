//
//  BitfinexExchange.swift
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
import Starscream
import SwiftyJSON
import PromiseKit

class BitfinexExchange: Exchange {

    private struct Constants {
        static let WebSocketURL = URL(string: "wss://api.bitfinex.com/ws/2")!
        static let ProductListAPIPath = "https://api-pub.bitfinex.com/v2/conf/pub:list:pair:exchange"
        static let CurrencyListAPIPath = "https://api-pub.bitfinex.com/v2/conf/pub:map:currency:label"
        static let TickerAPIPathFormat = "https://api.bitfinex.com/v2/tickers?symbols=%@"
    }

    init(delegate: ExchangeDelegate? = nil) {
        super.init(site: .bitfinex, delegate: delegate)
    }

    override func load() {
        _ = firstly {
            when(fulfilled: requestAPI(Constants.ProductListAPIPath), requestAPI(Constants.CurrencyListAPIPath))
        }.done { [weak self] (productsResponse, currenciesResponse) in
            var availableCurrencies: [String: Currency] = [:]
            for currency in currenciesResponse.json.arrayValue[0].arrayValue {
                guard let code = currency.arrayValue.first?.stringValue, let displayName = currency.arrayValue.last?.stringValue else {
                    continue
                }

                availableCurrencies[code] = Currency(code: code, customDisplayName: displayName, customSymbol: code)
            }

            let availableCurrencyPairs = productsResponse.json.arrayValue[0].arrayValue.compactMap { product -> CurrencyPair? in
                let pairString = product.stringValue
                let customCode = "t\(pairString.uppercased())"
                var baseCurrencyCode: String?
                var quoteCurrencyCode: String?
                if pairString.contains(":") {
                    let pairParts = pairString.split(separator: ":")
                    if let baseCurrencySubstring = pairParts.first, let quoteCurrencySubstring = pairParts.last {
                        baseCurrencyCode = String(baseCurrencySubstring)
                        quoteCurrencyCode = String(quoteCurrencySubstring)
                    }
                } else if pairString.count == 6 {
                    baseCurrencyCode = String(pairString.prefix(3))
                    quoteCurrencyCode = String(pairString.suffix(3))
                }

                guard let baseCurrencyCode = baseCurrencyCode, let quoteCurrencyCode = quoteCurrencyCode, let baseCurrency = availableCurrencies[baseCurrencyCode], let quoteCurrency = availableCurrencies[quoteCurrencyCode] else {
                    return CurrencyPair(baseCurrency: baseCurrencyCode, quoteCurrency: quoteCurrencyCode, customCode: customCode)
                }

                return CurrencyPair(
                    baseCurrency: baseCurrency,
                    quoteCurrency: quoteCurrency,
                    customCode: customCode
                )
            }

            self?.setAvailableCurrencyPairs(availableCurrencyPairs)
        }
    }

    override internal func fetch() {
        if isUpdatingInRealTime {
            let socket = WebSocket(request: URLRequest(url: Constants.WebSocketURL))
            socket.callbackQueue = socketResponseQueue

            var channelIds =  [String: Int]()
            selectedCurrencyPairs.forEach({ channelIds[$0.customCode] = 0 })
            socket.onEvent = { [weak self] event in
                switch event {
                case .connected(_):
                    channelIds.keys.forEach({ productId in
                        let json = JSON([
                            "event": "subscribe",
                            "channel": "ticker",
                            "symbol": productId
                        ])

                        if let string = json.rawString() {
                            socket.write(string: string)
                        }
                    })

                case .text(let text):
                    if let strongSelf = self {
                        let json = JSON(parseJSON: text)
                        if json["event"] == "subscribed" {
                            if let productId = json["symbol"].string {
                                channelIds[productId] = json["chanId"].intValue
                            }
                        } else if let data = json.array,
                            let channelId = data.first?.int,
                            let info = data.last?.array, info.count > 6,
                            let productId = channelIds.first(where: { $0.value == channelId })?.0,
                            let currencyPair = strongSelf.selectedCurrencyPair(withCustomCode: productId) {
                            let price = info[6].doubleValue
                            strongSelf.setPrice(price, for: currencyPair)
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
            let productIds: [String] = selectedCurrencyPairs.map({ $0.customCode })
            let apiPath = String(format: Constants.TickerAPIPathFormat, productIds.joined(separator: ","))
            requestAPI(apiPath).map { [weak self] result in
                result.json.arrayValue.forEach({ result in
                    let data = result.arrayValue
                    if data.count > 7, let currencyPair = self?.selectedCurrencyPair(withCustomCode: data.first!.stringValue) {
                        let price = data[7].doubleValue
                        self?.setPrice(price, for: currencyPair)
                    }
                })

                self?.onFetchComplete()
            }.catch { error in
                print("Error fetching Bitfinex ticker: \(error)")
            }
        }
    }

}
