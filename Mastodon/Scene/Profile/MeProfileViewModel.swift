//
//  MeProfileViewModel.swift
//  Mastodon
//
//  Created by MainasuK Cirno on 2021-3-30.
//

import os.log
import UIKit
import Combine
import CoreData
import CoreDataStack
import MastodonCore
import MastodonSDK

final class MeProfileViewModel: ProfileViewModel {
    
    init(context: AppContext, authContext: AuthContext) {
        let user = authContext.mastodonAuthenticationBox.authentication.user(in: context.cacheManagedObjectContext)
        super.init(
            context: context,
            authContext: authContext,
            optionalMastodonUser: user
        )
        
        $me
            .sink { [weak self] me in
                os_log("%{public}s[%{public}ld], %{public}s: current active mastodon user: %s", ((#file as NSString).lastPathComponent), #line, #function, me?.username ?? "<nil>")
                
                guard let self = self else { return }
                self.user = me
            }
            .store(in: &disposeBag)
    }

    override func viewDidLoad() {

        super.viewDidLoad()

        Task {
            do {

                _ = try await context.apiService.authenticatedUserInfo(authenticationBox: authContext.mastodonAuthenticationBox).value

                try await context.cacheManagedObjectContext.performChanges {
                    guard let me = self.authContext.mastodonAuthenticationBox.authentication.user(in: self.context.cacheManagedObjectContext) else {
                        assertionFailure()
                        return
                    }

                    self.me = me
                }
            } catch {
                // do nothing?
            }
        }
    }
}
