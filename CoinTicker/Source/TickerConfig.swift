//
//  TickerConfig.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
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

class TickerConfig {
    
    private struct Keys {
        static let UserDefaultsExchangeSite = "userDefaults.exchangeSite"
        static let UserDefaultsUpdateInterval = "userDefaults.updateInterval"
        static let UserDefaultsBaseCurrency = "userDefaults.baseCurrency"
        static let UserDefaultsQuoteCurrency = "userDefaults.quoteCurrency"
    }
    
    static let RealTimeUpdateInterval: Int = 5
    
    static var updateInterval: Int {
        get {
            let updateInterval = UserDefaults.standard.integer(forKey: Keys.UserDefaultsUpdateInterval)
            return (updateInterval > 0 ? updateInterval : RealTimeUpdateInterval)
        }
        
        set {
            let updateInterval = (newValue > 0 ? newValue : RealTimeUpdateInterval)
            UserDefaults.standard.set(updateInterval, forKey: Keys.UserDefaultsUpdateInterval)
        }
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
            
            if let currency = Currency.build(fromLocale: Locale.current) {
                return currency
            }
            
            return .usd
        }
        
        set {
            UserDefaults.standard.set(newValue.index, forKey: Keys.UserDefaultsQuoteCurrency)
        }
    }

}
