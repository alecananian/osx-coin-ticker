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
    //case campBX = "Camp BX" // http://CampBX.com/api/xticker.php
    case gdax = "GDAX"
    //case kraken = "Kraken" // https://www.kraken.com/help/api
    
    static let allValues = [bitstamp, gdax]
}

protocol ExchangeDelegate {
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double)
}

class Exchange {
    
    internal var site: ExchangeSite
    internal var delegate: ExchangeDelegate
    internal var currencyMatrix: [CryptoCurrency: [PhysicalCurrency]] = [.bitcoin: [.usd]]
    
    var currentCryptoCurrency = CryptoCurrency.bitcoin {
        didSet {
            if availablePhysicalCurrencies.contains(TickerConfig.defaultPhysicalCurrency) {
                currentPhysicalCurrency = TickerConfig.defaultPhysicalCurrency
            } else {
                currentPhysicalCurrency = availablePhysicalCurrencies.first!
            }
            
            TickerConfig.defaultCryptoCurrency = currentCryptoCurrency
        }
    }
    
    var currentPhysicalCurrency = PhysicalCurrency.usd {
        didSet {
            TickerConfig.defaultPhysicalCurrency = currentPhysicalCurrency
        }
    }
    
    var availableCryptoCurrencies: [CryptoCurrency] {
        return Array(currencyMatrix.keys)
    }
    
    var availablePhysicalCurrencies: [PhysicalCurrency] {
        return currencyMatrix[currentCryptoCurrency]!
    }
    
    static func build(withSite site: ExchangeSite, delegate: ExchangeDelegate) -> Exchange {
        switch site {
        case .bitstamp: return BitstampExchange(delegate: delegate)
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
        
    }
    
    func reset() {
        stop()
        start()
    }

}
