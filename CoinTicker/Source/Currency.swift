//
//  Currency.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/31/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Cocoa

enum Currency: Int {
    // Physical
    case cad = 10
    case cny = 20
    case eur = 30
    case gbp = 40
    case jpy = 50
    case rur = 60
    case usd = 70
    
    // Crypto
    case btc = 100
    case dsh = 110
    case etc = 120
    case eth = 130
    case gno = 140
    case icn = 150
    case ltc = 160
    case mln = 170
    case nmc = 180
    case nvc = 190
    case ppc = 200
    case rep = 210
    case usdt = 220
    case xdg = 230
    case xlm = 240
    case xmr = 250
    case xrp = 260
    case zec = 270
    
    static let AllPhysical = [cad, cny, eur, gbp, jpy, rur, usd]
    static let AllCrypto = [btc, eth, ltc, dsh, etc, gno, icn,
                            mln, nmc, nvc, ppc, rep, usdt, xdg,
                            xlm, xmr, xrp, zec]
    static let AllValues = AllCrypto + AllPhysical
    
    var code: String {
        return String(describing: self).uppercased()
    }
    
    var index: Int {
        return self.rawValue
    }
    
    var displayName: String {
        switch self {
        case .rep: return "Augur (REP)"
        case .btc: return "Bitcoin (BTC)"
        case .dsh: return "Dashcoin (DSH)"
        case .xdg: return "Dogecoin (XDG)"
        case .eth: return "Ethereum (ETH)"
        case .etc: return "Ethereum Classic (ETC)"
        case .gno: return "Gnosis (GNO)"
        case .icn: return "Iconomi (ICN)"
        case .ltc: return "Litecoin (LTC)"
        case .mln: return "Melon (MLN)"
        case .xmr: return "Monero (XMR)"
        case .nmc: return "Namecoin (NMC)"
        case .nvc: return "Novacoin (NVC)"
        case .ppc: return "Peercoin (PPC)"
        case .xrp: return "Ripple (XRP)"
        case .xlm: return "Stellar Lumens (XLM)"
        case .usdt: return "Tether (USDT)"
        case .zec: return "Zcash (ZEC)"
        default: return code
        }
    }
    
    var iconImage: NSImage? {
        return NSImage(named: code)
    }
    
    var isCrypto: Bool {
        return (self.rawValue >= 100)
    }
    
    static func build(fromCode code: String) -> Currency? {
        let normalizedCode = code.lowercased()
        return AllValues.first(where: { $0.code.lowercased() == normalizedCode })
    }
    
    static func build(fromIndex index: Int) -> Currency? {
        return Currency(rawValue: index)
    }
    
}
