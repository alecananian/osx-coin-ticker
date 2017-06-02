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
        static let UserDefaultsDisplayCurrency = "userDefaults.displayCurrency"
    }
    
    static var defaultExchangeSite: ExchangeSite {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: Keys.UserDefaultsExchangeSite) as? String, let exchangeSite = ExchangeSite(rawValue: rawValue) {
                return exchangeSite
            }
            
            return .gdax
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsExchangeSite)
        }
    }
    
    static var defaultBaseCurrency: Currency {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: Keys.UserDefaultsBaseCurrency) as? String, let currency = Currency(rawValue: rawValue) {
                return currency
            }
            
            return .bitcoin
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsBaseCurrency)
        }
    }
    
    static var defaultDisplayCurrency: Currency {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: Keys.UserDefaultsDisplayCurrency) as? String, let currency = Currency(rawValue: rawValue) {
                return currency
            }
            
            return .usd
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsDisplayCurrency)
        }
    }

}
