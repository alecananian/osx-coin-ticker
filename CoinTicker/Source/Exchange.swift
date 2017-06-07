//
//  Exchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation
import Cocoa
import Alamofire

enum ExchangeSite: Int {
    case bitstamp = 210
    case btcChina = 220
    case btce = 230
    case gdax = 240
    //case kraken = "Kraken" // https://www.kraken.com/help/api
    
    static let allValues = [bitstamp, btcChina, btce, gdax]
    
    var index: Int {
        return self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .bitstamp: return "Bitstamp"
        case .btcChina: return "BTCChina"
        case .btce: return "BTC-E"
        case .gdax: return "GDAX"
        }
    }
    
    static func build(fromIndex index: Int) -> ExchangeSite? {
        return ExchangeSite(rawValue: index)
    }
}

protocol ExchangeDelegate {
    func exchange(_ exchange: Exchange, didLoadCurrencyMatrix currencyMatrix: CurrencyMatrix)
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double)
}

typealias CurrencyMatrix = [Currency: [Currency]]
typealias JSONContainer = [String: Any]

class Exchange {
    
    internal var site: ExchangeSite
    internal var delegate: ExchangeDelegate
    internal var apiRequests = [DataRequest]()
    internal var currencyMatrix: CurrencyMatrix? {
        didSet {
            if availableBaseCurrencies.contains(TickerConfig.defaultBaseCurrency) {
                baseCurrency = TickerConfig.defaultBaseCurrency
            } else {
                baseCurrency = availableBaseCurrencies.first!
            }
        }
    }
    
    var baseCurrency = Currency.btc {
        didSet {
            if let availableQuoteCurrencies = currencyMatrix?[baseCurrency] {
                if availableQuoteCurrencies.contains(TickerConfig.defaultQuoteCurrency) {
                    quoteCurrency = TickerConfig.defaultQuoteCurrency
                } else if let localeCurrency = Currency.build(fromLocale: Locale.current), availableQuoteCurrencies.contains(localeCurrency) {
                    quoteCurrency = localeCurrency
                } else {
                    quoteCurrency = availableQuoteCurrencies.first!
                }
            }
            
            TickerConfig.defaultBaseCurrency = baseCurrency
        }
    }
    
    var quoteCurrency = Currency.usd {
        didSet {
            TickerConfig.defaultQuoteCurrency = quoteCurrency
        }
    }
    
    var availableBaseCurrencies: [Currency] {
        if let baseCurrencies = currencyMatrix?.keys {
            return Array(baseCurrencies).sorted(by: { $0.displayName < $1.displayName })
        }
        
        return [Currency]()
    }
    
    static func build(fromSite site: ExchangeSite, delegate: ExchangeDelegate) -> Exchange {
        switch site {
        case .bitstamp: return BitstampExchange(delegate: delegate)
        case .btcChina: return BTCChinaExchange(delegate: delegate)
        case .btce: return BTCEExchange(delegate: delegate)
        case .gdax: return GDAXExchange(delegate: delegate)
        }
    }
    
    init(site: ExchangeSite, delegate: ExchangeDelegate) {
        self.site = site
        self.delegate = delegate
    }
    
    func start() {
        
    }
    
    func stop() {
        apiRequests.forEach({ $0.cancel() })
    }
    
    func reset() {
        stop()
        start()
    }

}
