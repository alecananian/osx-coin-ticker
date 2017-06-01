//
//  Exchange.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation

enum ExchangeSite: String {
    case none = "None"
    case gdax = "GDAX"
    
    static let allValues = [gdax]
}

enum Currency: String {
    case usd = "USD"
    case eur = "EUR"
    
    static var allValues: [Currency] = [.usd, .eur]
}

enum CryptoCurrency: String {
    case bitcoin = "BTC"
    case ethereum = "ETH"
    case litecoin = "LTC"
    
    static var allValues: [CryptoCurrency] = [.bitcoin, .ethereum, .litecoin]
}

protocol ExchangeDelegate {
    func priceDidChange(price: Double)
}

class Exchange {
    
    internal var site = ExchangeSite.none
    internal var delegate: ExchangeDelegate
    internal var availableCryptoCurrencies = CryptoCurrency.allValues
    
    static func fromSite(_ site: ExchangeSite, delegate: ExchangeDelegate) -> Exchange {
        switch site {
        default:
            return GDAXExchange(site: site, delegate: delegate)
        }
    }
    
    required init(site: ExchangeSite, delegate: ExchangeDelegate) {
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
