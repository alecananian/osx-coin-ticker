//
//  AppDelegate.swift
//  CoinTicker
//
//  Created by Alec Ananian on 5/30/17.
//  Copyright © 2017 Alec Ananian. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    fileprivate let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    @IBOutlet private var statusBarMenu: NSMenu!
    @IBOutlet private var exchangeMenu: NSMenu!
    @IBOutlet private var cryptoCurrencyMenu: NSMenu!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        for exchangeSite in ExchangeSite.allValues {
            exchangeMenu.addItem(withTitle: exchangeSite.rawValue, action: #selector(onSelectExchangeSite(sender:)), keyEquivalent: "")
        }
        
        statusItem.menu = statusBarMenu
        
        setCurrentExchangeSite(ExchangeSite.allValues.first!)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    
    private func setCurrentExchangeSite(_ exchangeSite: ExchangeSite) {
        if TickerConfig.currentExchange == nil || exchangeSite.rawValue != TickerConfig.currentExchange!.site.rawValue {
            let exchange = Exchange.fromSite(exchangeSite, delegate: self)
            for cryptoCurrency in exchange.availableCryptoCurrencies {
                cryptoCurrencyMenu.addItem(withTitle: cryptoCurrency.rawValue, action: #selector(onSelectCryptoCurrency(sender:)), keyEquivalent: "")
            }
            
            for menuItem in exchangeMenu.items {
                menuItem.state = (menuItem.title == exchange.site.rawValue ? NSOnState : NSOffState)
            }
            
            setCurrentCryptoCurrency(exchange.availableCryptoCurrencies.first!)
            TickerConfig.currentExchange = exchange
        }
    }
    
    private func setCurrentCryptoCurrency(_ cryptoCurrency: CryptoCurrency) {
        let code = cryptoCurrency.rawValue
        for menuItem in cryptoCurrencyMenu.items {
            menuItem.state = (menuItem.title == code ? NSOnState : NSOffState)
        }
        
        let currencyImage = NSImage(named: code)
        currencyImage?.isTemplate = true
        statusItem.image = currencyImage
        
        TickerConfig.currentCryptoCurrency = cryptoCurrency
    }
    
    @objc private func onSelectExchangeSite(sender: AnyObject) {
        if let siteName = (sender as? NSMenuItem)?.title, let exchangeSite = ExchangeSite(rawValue: siteName) {
            setCurrentExchangeSite(exchangeSite)
        }
    }
    
    @objc private func onSelectCryptoCurrency(sender: AnyObject) {
        if let code = (sender as? NSMenuItem)?.title, let cryptoCurrency = CryptoCurrency(rawValue: code) {
            setCurrentCryptoCurrency(cryptoCurrency)
        }
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared().terminate(self)
    }

}

extension AppDelegate: ExchangeDelegate {
    
    func priceDidChange(price: Double) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = TickerConfig.currentCurrency.rawValue
        statusItem.title = currencyFormatter.string(for: price)
    }
    
}
