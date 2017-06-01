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
        static let UserDefaultsPhysicalCurrency = "userDefaults.physicalCurrency"
        static let UserDefaultsCryptoCurrency = "userDefaults.cryptoCurrency"
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
    
    static var defaultPhysicalCurrency: PhysicalCurrency {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: Keys.UserDefaultsPhysicalCurrency) as? String, let physicalCurrency = PhysicalCurrency(rawValue: rawValue) {
                return physicalCurrency
            }
            
            return .usd
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsPhysicalCurrency)
        }
    }
    
    static var defaultCryptoCurrency: CryptoCurrency {
        get {
            if let rawValue = UserDefaults.standard.value(forKey: Keys.UserDefaultsCryptoCurrency) as? String, let cryptoCurrency = CryptoCurrency(rawValue: rawValue) {
                return cryptoCurrency
            }
            
            return .bitcoin
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsCryptoCurrency)
        }
    }

}
