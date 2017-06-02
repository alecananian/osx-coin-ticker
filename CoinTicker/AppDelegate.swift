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
    @IBOutlet private var exchangeMenuItem: NSMenuItem!
    @IBOutlet private var currencyStartSeparator: NSMenuItem!
    private var currencyMenuItems = [NSMenuItem]()
    @IBOutlet private var quitMenuItem: NSMenuItem!
    
    fileprivate let statusItem = NSStatusBar.system().statusItem(withLength: NSVariableStatusItemLength)
    private var currentExchange: Exchange! {
        didSet {
            currencyMenuItems.forEach({ mainMenu.removeItem($0) })
            currencyMenuItems.removeAll()
            
            var itemIndex = mainMenu.index(of: currencyStartSeparator) + 1
            for baseCurrency in currentExchange.availableBaseCurrencies {
                let subMenu = NSMenu()
                currentExchange.currencyMatrix[baseCurrency]?.forEach({
                    let item = NSMenuItem(title: $0.rawValue, action: #selector(onSelectDisplayCurrency(sender:)), keyEquivalent: "")
                    subMenu.addItem(item)
                })
                
                let item = NSMenuItem(title: baseCurrency.rawValue, action: #selector(onSelectBaseCurrency(sender:)), keyEquivalent: "")
                item.submenu = subMenu
                mainMenu.insertItem(item, at: itemIndex)
                currencyMenuItems.append(item)
                
                itemIndex += 1
            }
            
            updateMenuStates()
            currentExchange.start()
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
            exchangeMenuItem.submenu?.addItem(withTitle: exchangeSite.rawValue, action: #selector(onSelectExchangeSite(sender:)), keyEquivalent: "")
        }
        
        // Load defaults
        currentExchange = Exchange.build(withSite: TickerConfig.defaultExchangeSite, delegate: self)
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        currentExchange.stop()
    }
    
    private func updateMenuStates() {
        exchangeMenuItem.submenu?.items.forEach({ $0.state = ($0.title == currentExchange.site.rawValue ? NSOnState : NSOffState) })
        currencyMenuItems.forEach({
            let isSelected = ($0.title == currentExchange.baseCurrency.rawValue)
            $0.state = (isSelected ? NSOnState : NSOffState)
            if let subMenu = $0.submenu {
                subMenu.items.forEach({ $0.state = (isSelected && $0.title == currentExchange.displayCurrency.rawValue ? NSOnState : NSOffState) })
            }
        })
        
        if let iconImage = currentExchange.baseCurrency.iconImage {
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
    
    @objc private func onSelectBaseCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let baseCurrency = Currency(rawValue: menuItem.title) {
            currentExchange.baseCurrency = baseCurrency
            currentExchange.reset()
            updateMenuStates()
        }
    }
    
    @objc private func onSelectDisplayCurrency(sender: AnyObject) {
        if let menuItem = sender as? NSMenuItem, let parentMenuItem = menuItem.parent, let displayCurrency = Currency(rawValue: menuItem.title), let baseCurrency = Currency(rawValue: parentMenuItem.title) {
            currentExchange.baseCurrency = baseCurrency
            currentExchange.displayCurrency = displayCurrency
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
        currencyFormatter.currencyCode = exchange.displayCurrency.rawValue
        statusItem.title = currencyFormatter.string(for: price)
    }
    
}
