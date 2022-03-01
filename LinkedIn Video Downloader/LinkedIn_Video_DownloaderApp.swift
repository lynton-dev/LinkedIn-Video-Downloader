//
//  LinkedIn_Video_DownloaderApp.swift
//  LinkedIn Video Downloader
//
//  Created by Lynton Schoeman on 2022-02-28.
//

import SwiftUI

@main
struct LinkedIn_Video_DownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
         return true
    }
}
