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

protocol TickerConfigDelegate {
    
    func didSelectUpdateInterval()
    func didUpdateSelectedCurrencyPairs()
    func didUpdatePrices()
    
}

class TickerConfig {
    
    private struct Keys {
        static let UserDefaultsExchangeSite = "userDefaults.exchangeSite"
        static let UserDefaultsUpdateInterval = "userDefaults.updateInterval"
        static let UserDefaultsSelectedCurrencyPairCodes = "userDefaults.selectedCurrencyPairCodes"
    }
    
    private struct Constants {
        static let RealTimeUpdateInterval: Int = 5
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
    
    static var delegate: TickerConfigDelegate?
    
    private static var _selectedUpdateInterval: Int!
    static var selectedUpdateInterval: Int {
        if _selectedUpdateInterval == nil {
            let updateInterval = UserDefaults.standard.integer(forKey: Keys.UserDefaultsUpdateInterval)
            _selectedUpdateInterval = (updateInterval > 0 ? updateInterval : Constants.RealTimeUpdateInterval)
            delegate?.didSelectUpdateInterval()
        }
        
        return _selectedUpdateInterval
    }
    
    static func select(updateInterval: Int) {
        _selectedUpdateInterval = updateInterval
        save()
        delegate?.didSelectUpdateInterval()
        TrackingUtils.didSelectUpdateInterval(updateInterval)
    }
    
    static var isRealTimeUpdateIntervalSelected: Bool {
        return (selectedUpdateInterval == Constants.RealTimeUpdateInterval)
    }
    
    private static var _selectedCurrencyPairs: [CurrencyPair]!
    static var selectedCurrencyPairs: [CurrencyPair] {
        if _selectedCurrencyPairs == nil {
            _selectedCurrencyPairs = [CurrencyPair]()
            if let selectedCurrencyPairCodes = UserDefaults.standard.object(forKey: Keys.UserDefaultsSelectedCurrencyPairCodes) as? [String] {
                selectedCurrencyPairCodes.forEach({ (currencyPairCode) in
                    if let currencyPair = CurrencyPair(code: currencyPairCode) {
                        _selectedCurrencyPairs.append(currencyPair)
                    }
                })
                
                delegate?.didUpdateSelectedCurrencyPairs()
            }
        }
        
        return _selectedCurrencyPairs
    }
    
    static var selectedCurrencyPairCodes: [String] {
        return selectedCurrencyPairs.map({ $0.code })
    }
    
    static func toggle(currencyPair: CurrencyPair) -> Bool {
        if selectedCurrencyPairs.contains(currencyPair) {
            if selectedCurrencyPairs.count > 1 {
                deselectCurrencyPair(currencyPair)
                return false
            }
        } else {
            _selectedCurrencyPairs.append(currencyPair)
            _selectedCurrencyPairs = _selectedCurrencyPairs.sorted()
            save()
            delegate?.didUpdateSelectedCurrencyPairs()
            TrackingUtils.didSelectCurrencyPair(currencyPair)
        }
        
        return true
    }
    
    static func toggle(baseCurrency: Currency, quoteCurrency: Currency) -> Bool {
        let currencyPair = CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
        return toggle(currencyPair: currencyPair)
    }
    
    static func deselectCurrencyPair(_ currencyPair: CurrencyPair) {
        if let index = _selectedCurrencyPairs.index(of: currencyPair) {
            _selectedCurrencyPairs.remove(at: index)
            save()
            delegate?.didUpdateSelectedCurrencyPairs()
            TrackingUtils.didDeselectCurrencyPair(currencyPair)
        }
    }
    
    private static var _currencyPairPrices = [CurrencyPair: Double]()
    static func setPrice(_ price: Double, forCurrencyPair currencyPair: CurrencyPair) {
        _currencyPairPrices[currencyPair] = price
        delegate?.didUpdatePrices()
    }
    
    static func setPrice(_ price: Double, forBaseCurrency baseCurrency: Currency, quoteCurrency: Currency) {
        let currencyPair = CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
        setPrice(price, forCurrencyPair: currencyPair)
    }
    
    static func setPrice(_ price: Double, forCurrencyPairCode currencyPairCode: String) {
        if let currencyPair = CurrencyPair(code: currencyPairCode) {
            setPrice(price, forCurrencyPair: currencyPair)
        }
    }
    
    static func price(for currencyPair: CurrencyPair) -> Double {
        guard let price = _currencyPairPrices[currencyPair] else {
            return 0
        }
        
        return price
    }
    
    static func isWatching(baseCurrency: Currency) -> Bool {
        return selectedCurrencyPairs.contains(where: { $0.baseCurrency == baseCurrency })
    }
    
    static func isWatching(baseCurrency: Currency, quoteCurrency: Currency) -> Bool {
        let currencyPair = CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
        return selectedCurrencyPairs.contains(currencyPair)
    }
    
    static func save() {
        UserDefaults.standard.set(selectedCurrencyPairCodes, forKey: Keys.UserDefaultsSelectedCurrencyPairCodes)
        UserDefaults.standard.set(selectedUpdateInterval, forKey: Keys.UserDefaultsUpdateInterval)
    }

}
