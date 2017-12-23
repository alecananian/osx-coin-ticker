//
//  CurrencyPair.swift
//  CoinTicker
//
//  Created by Alec Ananian on 11/19/17.
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

struct CurrencyPair: Hashable, Comparable {
    
    var baseCurrency: Currency
    var quoteCurrency: Currency
    
    init(baseCurrency: Currency, quoteCurrency: Currency) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
    }
    
    init?(baseCurrency: String?, quoteCurrency: String?) {
        guard let baseCurrencyString = baseCurrency, let quoteCurrencyString = quoteCurrency else {
            return nil
        }
        
        guard let baseCurrency = Currency.build(fromCode: baseCurrencyString), let quoteCurrency = Currency.build(fromCode: quoteCurrencyString) else {
            return nil
        }
        
        self = CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency)
    }
    
    init?(code: String, separator: String = "-") {
        let currencyCodes = code.split(separator: "-")
        guard currencyCodes.count == 2 else {
            return nil
        }
        
        guard let currencyPair = CurrencyPair(baseCurrency: String(currencyCodes.first!), quoteCurrency: String(currencyCodes.last!)) else {
            return nil
        }
        
        self = currencyPair
    }
    
    var code: String {
        return code(withSeparator: "-")
    }
    
    var hashValue: Int {
        return code.hashValue
    }
    
    func code(withSeparator separator: Character) -> String {
        return "\(baseCurrency.code)\(separator)\(quoteCurrency.code)"
    }
    
    static func <(lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        return (
            (lhs.baseCurrency.isBitcoin && !rhs.baseCurrency.isBitcoin) ||
            (lhs.baseCurrency.isBitcoinCash && !rhs.baseCurrency.isBitcoin && !rhs.baseCurrency.isBitcoinCash) ||
            (lhs.baseCurrency == rhs.baseCurrency && (
                (lhs.quoteCurrency.isBitcoin && !rhs.quoteCurrency.isBitcoin) ||
                (lhs.quoteCurrency.code < rhs.quoteCurrency.code)
            )) ||
            (lhs.baseCurrency.code < rhs.baseCurrency.code)
        )
    }
    
    static func == (lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        return (lhs.baseCurrency == rhs.baseCurrency && lhs.quoteCurrency == rhs.quoteCurrency)
    }
    
}
