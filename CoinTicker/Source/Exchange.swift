//
//  Exchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation
import Cocoa

enum ExchangeSite: String {
    case bitstamp = "Bitstamp"
    //case btce = "BTC-E" // https://btc-e.com/api/3/docs#ticker
    //case btcChina = "BTCChina" // https://www.btcchina.com/apidocs/
    case gdax = "GDAX"
    //case kraken = "Kraken" // https://www.kraken.com/help/api
    
    static let allValues = [bitstamp, gdax]
    
    var displayName: String {
        return self.rawValue
    }
}

protocol ExchangeDelegate {
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double)
}

typealias CurrencyMatrix = [Currency: [Currency]]

class Exchange {
    
    internal var site: ExchangeSite
    internal var delegate: ExchangeDelegate
    internal var currencyMatrix: CurrencyMatrix
    
    var baseCurrency = Currency.bitcoin {
        didSet {
            if let availableDisplayCurrencies = currencyMatrix[baseCurrency] {
                if availableDisplayCurrencies.contains(TickerConfig.defaultDisplayCurrency) {
                    displayCurrency = TickerConfig.defaultDisplayCurrency
                } else {
                    displayCurrency = availableDisplayCurrencies.first!
                }
            }
            
            TickerConfig.defaultBaseCurrency = baseCurrency
        }
    }
    
    var displayCurrency = Currency.usd {
        didSet {
            TickerConfig.defaultDisplayCurrency = displayCurrency
        }
    }
    
    var availableBaseCurrencies: [Currency] {
        return Array(currencyMatrix.keys).sorted(by: { $0.displayName < $1.displayName })
    }
    
    static func build(withSite site: ExchangeSite, delegate: ExchangeDelegate) -> Exchange {
        switch site {
        case .bitstamp: return BitstampExchange(delegate: delegate)
        case .gdax: return GDAXExchange(delegate: delegate)
        }
    }
    
    init(site: ExchangeSite, delegate: ExchangeDelegate, currencyMatrix: CurrencyMatrix) {
        self.site = site
        self.delegate = delegate
        self.currencyMatrix = currencyMatrix
        
        defer {
            if availableBaseCurrencies.contains(TickerConfig.defaultBaseCurrency) {
                baseCurrency = TickerConfig.defaultBaseCurrency
            } else {
                baseCurrency = availableBaseCurrencies.first!
            }
        }
    }
    
    func start() {
        
    }
    
    func stop() {
        
    }
    
    func reset() {
        stop()
        start()
    }

}
