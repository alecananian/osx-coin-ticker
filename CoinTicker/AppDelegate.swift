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

    @IBOutlet private var mainMenu: NSMenu!
    @IBOutlet fileprivate var exchangesSubMenu: NSMenu!
    @IBOutlet fileprivate var cryptoCurrencySubMenu: NSMenu!
    @IBOutlet fileprivate var physicalCurrencySubMenu: NSMenu!
    
    fileprivate let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    fileprivate var currentExchange: Exchange! {
        didSet {
            cryptoCurrencySubMenu.removeAllItems()
            
            for cryptoCurrency in currentExchange.availableCryptoCurrencies {
                cryptoCurrencySubMenu.addItem(withTitle: cryptoCurrency.rawValue, action: #selector(onSelectCryptoCurrency(sender:)), keyEquivalent: "")
            }
            
            updateCurrencyMenu()
            updateMenuStates()
            currentExchange.start()
            
            TickerConfig.defaultExchangeSite = currentExchange.site
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the main menu
        statusItem.menu = mainMenu
        
        // Set up exchange sub-menu
        for exchangeSite in ExchangeSite.allValues {
            exchangesSubMenu.addItem(withTitle: exchangeSite.rawValue, action: #selector(onSelectExchangeSite(sender:)), keyEquivalent: "")
        }
        
        // Load defaults
        currentExchange = Exchange.build(withSite: TickerConfig.defaultExchangeSite, delegate: self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        currentExchange.stop()
    }
    
    private func updateCurrencyMenu() {
        physicalCurrencySubMenu.removeAllItems()
        
        for physicalCurrency in currentExchange.availablePhysicalCurrencies {
            physicalCurrencySubMenu.addItem(withTitle: physicalCurrency.rawValue, action: #selector(onSelectPhysicalCurrency(sender:)), keyEquivalent: "")
        }
    }
    
    private func updateMenuStates() {
        for menuItem in exchangesSubMenu.items {
            menuItem.state = (menuItem.title == currentExchange.site.rawValue ? NSOnState : NSOffState)
        }
        
        for menuItem in cryptoCurrencySubMenu.items {
            menuItem.state = (menuItem.title == currentExchange.currentCryptoCurrency.rawValue ? NSOnState : NSOffState)
        }
        
        for menuItem in physicalCurrencySubMenu.items {
            menuItem.state = (menuItem.title == currentExchange.currentPhysicalCurrency.rawValue ? NSOnState : NSOffState)
        }
        
        if let iconImage = currentExchange.currentCryptoCurrency.iconImage {
            iconImage.isTemplate = true
            statusItem.image = iconImage
        }
    }
    
    @objc private func onSelectExchangeSite(sender: AnyObject) {
        if let siteName = (sender as? NSMenuItem)?.title, let exchangeSite = ExchangeSite(rawValue: siteName) {
            if exchangeSite != currentExchange.site {
                currentExchange.stop()
                currentExchange = Exchange.build(withSite: exchangeSite, delegate: self)
            }
        }
    }
    
    @objc fileprivate func onSelectCryptoCurrency(sender: AnyObject) {
        if let code = (sender as? NSMenuItem)?.title, let cryptoCurrency = CryptoCurrency(rawValue: code) {
            currentExchange.currentCryptoCurrency = cryptoCurrency
            currentExchange.reset()
            updateCurrencyMenu()
            updateMenuStates()
        }
    }
    
    @objc fileprivate func onSelectPhysicalCurrency(sender: AnyObject) {
        if let code = (sender as? NSMenuItem)?.title, let physicalCurrency = PhysicalCurrency(rawValue: code) {
            currentExchange.currentPhysicalCurrency = physicalCurrency
            currentExchange.reset()
            updateMenuStates()
        }
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared().terminate(self)
    }

}

extension AppDelegate: ExchangeDelegate {
    
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = exchange.currentPhysicalCurrency.rawValue
        statusItem.title = currencyFormatter.string(for: price)
    }
    
}
