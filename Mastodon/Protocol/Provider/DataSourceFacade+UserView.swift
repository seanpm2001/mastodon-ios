// Copyright © 2023 Mastodon gGmbH. All rights reserved.

import Foundation
import MastodonUI
import MastodonCore
import MastodonSDK

extension DataSourceFacade {
    static func responseToUserViewButtonAction(
        dependency: NeedsDependency & AuthContextProvider,
        user: Mastodon.Entity.Account,
        buttonState: UserView.ButtonState
    ) async throws {
        switch buttonState {
            case .follow:
                try await DataSourceFacade.responseToUserFollowAction(
                    dependency: dependency,
                    user: user
                )

                dependency.authContext.mastodonAuthenticationBox.inMemoryCache.followingUserIds.append(user.id)

            case .request:
                try await DataSourceFacade.responseToUserFollowAction(
                    dependency: dependency,
                    user: user
                )

                dependency.authContext.mastodonAuthenticationBox.inMemoryCache.followRequestedUserIDs.append(user.id)
            case .unfollow:
                try await DataSourceFacade.responseToUserFollowAction(
                    dependency: dependency,
                    user: user
                )

                dependency.authContext.mastodonAuthenticationBox.inMemoryCache.followingUserIds.removeAll(where: { $0 == user.id })
            case .blocked:
                try await DataSourceFacade.responseToUserBlockAction(
                    dependency: dependency,
                    user: user
                )

                dependency.authContext.mastodonAuthenticationBox.inMemoryCache.blockedUserIds.append(user.id)

            case .pending:
                try await DataSourceFacade.responseToUserFollowAction(
                    dependency: dependency,
                    user: user
                )

                dependency.authContext.mastodonAuthenticationBox.inMemoryCache.followRequestedUserIDs.removeAll(where: { $0 == user.id })
            case .none, .loading:
                break //no-op
        }
    }
}
