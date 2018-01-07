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

struct CurrencyPair: Comparable, Codable {
    
    var baseCurrency: Currency
    var quoteCurrency: Currency
    var customCode: String
    
    init(baseCurrency: Currency, quoteCurrency: Currency, customCode: String? = nil) {
        self.baseCurrency = baseCurrency
        self.quoteCurrency = quoteCurrency
        
        if let customCode = customCode {
            self.customCode = customCode
        } else {
            self.customCode = "\(baseCurrency.code)\(quoteCurrency.code)"
        }
    }
    
    init?(baseCurrency: String?, quoteCurrency: String?, customCode: String? = nil) {
        guard let baseCurrencyString = baseCurrency, let quoteCurrencyString = quoteCurrency else {
            return nil
        }
        
        guard let baseCurrency = Currency.build(fromCode: baseCurrencyString), let quoteCurrency = Currency.build(fromCode: quoteCurrencyString) else {
            return nil
        }
        
        self = CurrencyPair(baseCurrency: baseCurrency, quoteCurrency: quoteCurrency, customCode: customCode)
    }
    
}

extension CurrencyPair: CustomStringConvertible {
    
    var description: String {
        return "\(baseCurrency.code)\(quoteCurrency.code)"
    }
    
}

extension CurrencyPair: Hashable {
    
    var hashValue: Int {
        return String(describing: self).hashValue
    }
    
}

extension CurrencyPair: Equatable {
    
    static func <(lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        if lhs.baseCurrency == rhs.baseCurrency {
            return lhs.quoteCurrency < rhs.quoteCurrency
        }
        
        return lhs.baseCurrency < rhs.baseCurrency
    }
    
    static func == (lhs: CurrencyPair, rhs: CurrencyPair) -> Bool {
        return (lhs.baseCurrency == rhs.baseCurrency && lhs.quoteCurrency == rhs.quoteCurrency)
    }
    
}
