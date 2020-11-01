//
//  Currency.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/31/17.
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

import Cocoa

struct Currency: Codable {
    
    var code: String
    
    init?(code: String?) {
        guard var normalizedCode = code?.uppercased(), normalizedCode != "123" else {
            return nil
        }
        
        // Further normalization for Kraken API which prefixes X for crypto currencies and Z for physical
        if normalizedCode.count >= 4 && (normalizedCode.first == "X" || normalizedCode.first == "Z") {
            normalizedCode = String(normalizedCode.suffix(normalizedCode.count - 1))
        }
        
        self.code = normalizedCode
    }
    
    var displayName: String {
        let displayNameKey = "currency.\(internalCode.lowercased()).title"
        let displayName = String.LocalizedStringWithFallback(displayNameKey, comment: "Currency Title")
        return (displayName != displayNameKey && displayName != code ? "\(code) (\(displayName))" : code)
    }
    
    var symbol: String? {
        switch internalCode {
        case "AUD": return "$"
        case "BRL": return "R$"
        case "BTC", "BCH": return "₿"
        case "DOGE": return "Ð"
        case "ETC": return "⟠"
        case "ETH": return "Ξ"
        case "LTC": return "Ł"
        case "NGN": return "₦"
        case "NMC": return "ℕ"
        case "PPC": return "Ᵽ"
        case "REP": return "Ɍ"
        case "RUB": return "₽"
        case "TRY": return "₺"
        case "UAH": return "₴"
        case "USDS": return "USDⓈ"
        case "XMR": return "ɱ"
        case "XRP": return "Ʀ"
        case "ZAR": return "R"
        case "ZEC": return "ⓩ"
        default: return (isPhysical ? nil : code)
        }
    }
    
    // Normalize varying codes from different exchanges internally so we can equate currencies
    private var internalCode: String {
        switch code {
        case "RUR": return "RUB"
        case "BCC": return "BCH"
        case "DSH": return "DASH"
        case "IOT": return "IOTA"
        case "QSH": return "QASH"
        case "QTM": return "QTUM"
        case "XBT": return "BTC"
        case "XDG": return "DOGE"
        case "XRB": return "NANO"
        case "YYW": return "YOYO"
        default: return code
        }
    }
    
    var iconImage: NSImage? {
        return (NSImage(named: internalCode) ?? smallIconImage)
    }
    
    var smallIconImage: NSImage? {
        return NSImage(named: "\(internalCode)_small")
    }
    
    var isPhysical: Bool {
        return [
            "AUD",
            "BRL",
            "CAD",
            "CNY",
            "EUR",
            "GBP",
            "JPY",
            "KRW",
            "NGN",
            "RUB",
            "TRY",
            "UAH",
            "USD",
            "ZAR",
        ].contains(internalCode)
    }
    
    var isBitcoin: Bool {
        return (internalCode == "BTC")
    }
    
}

extension Currency: Hashable {
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }
    
}

extension Currency: Equatable {
    
    static func <(lhs: Currency, rhs: Currency) -> Bool {
        if lhs.isBitcoin && !rhs.isBitcoin {
            return true
        }
        
        if !lhs.isBitcoin && rhs.isBitcoin {
            return false
        }
        
        return lhs.code < rhs.code
    }
    
    static func ==(lhs: Currency, rhs: Currency) -> Bool {
        return lhs.internalCode == rhs.internalCode
    }
    
}
