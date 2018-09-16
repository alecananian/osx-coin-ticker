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
import Cocoa

class TickerConfig {
    
    private struct Keys {
        static let UserDefaultsExchangeSite = "userDefaults.exchangeSite"
        static let UserDefaultsUpdateInterval = "userDefaults.updateInterval"
        static let UserDefaultsShowIcon = "userDefaults.showIcon"
        static let UserDefaultsSelectedCurrencyPairs = "userDefaults.selectedCurrencyPairs"
    }
    
    struct Constants {
        static let RealTimeUpdateInterval: Int = 5
    }
    
    static let LogoImage = NSImage(named: "CTLogo")!
    static let SmallLogoImage = NSImage(named: "CTLogo_small")!
    
    static var defaultExchange: Exchange {
        let exchange = defaultExchangeSite.exchange()
        exchange.updateInterval = defaultUpdateInterval
        if let selectedCurrencyPairs = defaultSelectedCurrencyPairs {
            exchange.selectedCurrencyPairs = selectedCurrencyPairs
        }
        
        return exchange
    }
    
    private static var defaultExchangeSite: ExchangeSite {
        get {
            let index = UserDefaults.standard.integer(forKey: Keys.UserDefaultsExchangeSite)
            return ExchangeSite(rawValue: index) ?? .binance
        }
        
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: Keys.UserDefaultsExchangeSite)
        }
    }
    
    static var defaultUpdateInterval: Int {
        get {
            let updateInterval = UserDefaults.standard.integer(forKey: Keys.UserDefaultsUpdateInterval)
            return (updateInterval > 0 ? updateInterval : Constants.RealTimeUpdateInterval)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.UserDefaultsUpdateInterval)
        }
    }
    
    static var showsIcon: Bool {
        get {
            guard UserDefaults.standard.value(forKey: Keys.UserDefaultsShowIcon) != nil else {
                return true
            }
            
            return UserDefaults.standard.bool(forKey: Keys.UserDefaultsShowIcon)
        }
        
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.UserDefaultsShowIcon)
        }
    }
    
    private static var defaultSelectedCurrencyPairs: [CurrencyPair]? {
        get {
            if let data = UserDefaults.standard.object(forKey: Keys.UserDefaultsSelectedCurrencyPairs) as? Data {
                do {
                    return try JSONDecoder().decode([CurrencyPair].self, from: data)
                } catch {
                    print("Error reading from UserDefaults: \(error)")
                }
            }
            
            return []
        }
        
        set {
            do {
                UserDefaults.standard.set(try JSONEncoder().encode(newValue), forKey: Keys.UserDefaultsSelectedCurrencyPairs)
            } catch {
                print("Error saving to UserDefaults: \(error)")
            }
        }
    }
    
    static func save(_ defaultExchange: Exchange) {
        defaultExchangeSite = defaultExchange.site
        defaultUpdateInterval = defaultExchange.updateInterval
        defaultSelectedCurrencyPairs = defaultExchange.selectedCurrencyPairs
    }

}
