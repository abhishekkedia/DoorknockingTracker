//
//  DoorknockingTrackerApp.swift
//  DoorknockingTracker
//
//  Created by Abhishek Kedia on 28/05/2025.
//

import SwiftUI
import GoogleSignIn

@main
struct DoorknockingTracker: App {
    var body: some Scene {
        WindowGroup {
            RootAppView()
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
