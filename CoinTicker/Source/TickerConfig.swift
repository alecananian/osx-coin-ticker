//
//  TickerConfig.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Foundation

class TickerConfig {
    
    private struct Keys {
        static let UserDefaultsExchangeSite = "userDefaults.exchangeSite"
        static let UserDefaultsBaseCurrency = "userDefaults.baseCurrency"
        static let UserDefaultsQuoteCurrency = "userDefaults.quoteCurrency"
    }
    
    static var defaultExchangeSite: ExchangeSite {
        get {
            let index = UserDefaults.standard.integer(forKey: Keys.UserDefaultsExchangeSite)
            if let exchangeSite = ExchangeSite.build(fromIndex: index) {
                return exchangeSite
            }
            
            return .gdax
        }
        
        set {
            UserDefaults.standard.set(newValue.index, forKey: Keys.UserDefaultsExchangeSite)
        }
    }
    
    static var defaultBaseCurrency: Currency {
        get {
            let index = UserDefaults.standard.integer(forKey: Keys.UserDefaultsBaseCurrency)
            if let currency = Currency.build(fromIndex: index) {
                return currency
            }
            
            return .btc
        }
        
        set {
            UserDefaults.standard.set(newValue.index, forKey: Keys.UserDefaultsBaseCurrency)
        }
    }
    
    static var defaultQuoteCurrency: Currency {
        get {
            let index = UserDefaults.standard.integer(forKey: Keys.UserDefaultsQuoteCurrency)
            if let currency = Currency.build(fromIndex: index) {
                return currency
            }
            
            return .usd
        }
        
        set {
            UserDefaults.standard.set(newValue.index, forKey: Keys.UserDefaultsQuoteCurrency)
        }
    }

}
