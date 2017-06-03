//
//  Currency.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/31/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Cocoa

enum Currency: String {
    // Physical
    case cad = "CAD"
    case cny = "CNY"
    case eur = "EUR"
    case gbp = "GBP"
    case jpg = "JPY"
    case rur = "RUR"
    case usd = "USD"
    
    // Crypto
    case augur = "Augur (REP)"
    case bitcoin = "Bitcoin (BTC)"
    case dashcoin = "Dashcoin (DSH)"
    case dogecoin = "Dogecoin (XDG)"
    case ethereum = "Ethereum (ETH)"
    case ethereumClassic = "Ethereum Classic (ETC)"
    case gnosis = "Gnosis (GNO)"
    case iconomi = "Iconomi (ICN)"
    case litecoin = "Litecoin (LTC)"
    case melon = "Melon (MLN)"
    case monero = "Monero (XMR)"
    case namecoin = "Namecoin (NMC)"
    case novacoin = "Novacoin (NVC)"
    case peercoin = "Peercoin (PPC)"
    case ripple = "Ripple (XRP)"
    case stellarLumens = "Stellar Lumens (XLM)"
    case tether = "Tether (USDT)"
    case zcash = "Zcash (ZEC)"
    
    var code: String {
        if let range = self.rawValue.range(of: "\\(\\w+\\)", options: .regularExpression) {
            return self.rawValue.substring(with: range).replacingOccurrences(of: "(", with: "").replacingOccurrences(of: ")", with: "")
        }
        
        return self.rawValue
    }
    
    var displayName: String {
        if self.rawValue.contains("(") {
            return self.rawValue
        }
        
        return code
    }
    
    var iconImage: NSImage? {
        switch self {
        case .bitcoin: return NSImage(named: "BTC")
        case .ethereum: return NSImage(named: "ETH")
        case .litecoin: return NSImage(named: "LTC")
        case .ripple: return NSImage(named: "XRP")
        default: return nil
        }
    }
}
