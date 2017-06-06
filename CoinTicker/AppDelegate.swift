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

    @IBOutlet fileprivate var mainMenu: NSMenu!
    @IBOutlet fileprivate var exchangeMenuItem: NSMenuItem!
    @IBOutlet fileprivate var currencyStartSeparator: NSMenuItem!
    fileprivate var currencyMenuItems = [NSMenuItem]()
    @IBOutlet private var quitMenuItem: NSMenuItem!
    
    fileprivate let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    
    private var currentExchange: Exchange! {
        didSet {
            TickerConfig.defaultExchangeSite = currentExchange.site
        }
    }

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Set the main menu
        statusItem.menu = mainMenu
        
        // Update translations
        exchangeMenuItem.title = NSLocalizedString("menu.exchange.title", comment: "Exchange")
        quitMenuItem.title = NSLocalizedString("menu.quit.title", comment: "Quit")
        
        // Set up exchange sub-menu
        for exchangeSite in ExchangeSite.allValues {
            let item = NSMenuItem(title: exchangeSite.displayName, action: #selector(onSelectExchangeSite(sender:)), keyEquivalent: "")
            item.tag = exchangeSite.index
            exchangeMenuItem.submenu?.addItem(item)
        }
        
        // Load defaults
        currentExchange = Exchange.build(fromSite: TickerConfig.defaultExchangeSite, delegate: self)
        currentExchange.start()
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        currentExchange.stop()
    }
    
    fileprivate func updateMenuStates(forExchange exchange: Exchange) {
        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.tag == exchange.site.index ? NSOnState : NSOffState) })
        
        for menuItem in currencyMenuItems {
            let isSelected = (menuItem.tag == exchange.baseCurrency.index)
            menuItem.state = (isSelected ? NSOnState : NSOffState)
            if let subMenu = menuItem.submenu {
                subMenu.items.forEach({ $0.state = (isSelected && $0.tag == exchange.quoteCurrency.index ? NSOnState : NSOffState) })
            }
        }
        
        if let iconImage = exchange.baseCurrency.iconImage {
            iconImage.isTemplate = true
            statusItem.image = iconImage
        } else {
            statusItem.image = nil
        }
    }
    
    @objc private func onSelectExchangeSite(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let exchangeSite = ExchangeSite.build(fromIndex: menuItem.tag) {
            if exchangeSite != currentExchange.site {
                currentExchange.stop()
                currentExchange = Exchange.build(fromSite: exchangeSite, delegate: self)
                currentExchange.start()
            }
        }
    }
    
    @objc fileprivate func onSelectBaseCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let baseCurrency = Currency.build(fromIndex: menuItem.tag) {
            currentExchange.baseCurrency = baseCurrency
            currentExchange.reset()
            updateMenuStates(forExchange: currentExchange)
        }
    }
    
    @objc fileprivate func onSelectQuoteCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let parentMenuItem = menuItem.parent, let quoteCurrency = Currency.build(fromIndex: menuItem.tag), let baseCurrency = Currency.build(fromIndex: parentMenuItem.tag) {
            currentExchange.baseCurrency = baseCurrency
            currentExchange.quoteCurrency = quoteCurrency
            currentExchange.reset()
            updateMenuStates(forExchange: currentExchange)
        }
    }
    
    @IBAction private func onQuit(sender: AnyObject) {
        NSApplication.shared().terminate(self)
    }

}

extension AppDelegate: ExchangeDelegate {
    
    func exchange(_ exchange: Exchange, didLoadCurrencyMatrix currencyMatrix: CurrencyMatrix) {
        currencyMenuItems.forEach({ mainMenu.removeItem($0) })
        currencyMenuItems.removeAll()
        
        var itemIndex = mainMenu.index(of: currencyStartSeparator) + 1
        for baseCurrency in exchange.availableBaseCurrencies {
            let subMenu = NSMenu()
            currencyMatrix[baseCurrency]?.forEach({
                let item = NSMenuItem(title: $0.displayName, action: #selector(onSelectQuoteCurrency(sender:)), keyEquivalent: "")
                item.tag = $0.index
                subMenu.addItem(item)
            })
            
            let item = NSMenuItem(title: baseCurrency.displayName, action: #selector(onSelectBaseCurrency(sender:)), keyEquivalent: "")
            item.tag = baseCurrency.index
            item.submenu = subMenu
            mainMenu.insertItem(item, at: itemIndex)
            currencyMenuItems.append(item)
            
            itemIndex += 1
        }
        
        updateMenuStates(forExchange: exchange)
    }
    
    func exchange(_ exchange: Exchange, didUpdatePrice price: Double) {
        let currencyFormatter = NumberFormatter()
        currencyFormatter.numberStyle = .currency
        currencyFormatter.currencyCode = exchange.quoteCurrency.code
        currencyFormatter.maximumFractionDigits = (price < 0.01 ? 4 : 2)
        DispatchQueue.main.async {
            self.statusItem.title = currencyFormatter.string(for: price)
        }
    }
    
}
