//
//  DataSourceProvider+StatusTableViewCellDelegate.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-13.
//

import UIKit
import MetaTextKit
import MastodonCore
import MastodonUI
import MastodonLocalization
import MastodonAsset
import LinkPresentation
import MastodonSDK

// MARK: - header
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        headerDidPressed header: UIView
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            
            switch await statusView.viewModel.header {
            case .none:
                break
            case .reply:
                let account = try await context.apiService.accountLookup(
                    domain: authContext.mastodonAuthenticationBox.domain,
                    query: .init(acct: status.account.id),
                    authorization: authContext.mastodonAuthenticationBox.userAuthorization
                ).singleOutput().value
                
                await DataSourceFacade.coordinateToProfileScene(
                    provider: self,
                    user: account
                )

            case .repost:
                await DataSourceFacade.coordinateToProfileScene(
                    provider: self,
                    target: .reblog,      // keep the wrapper for header author
                    status: status
                )
            }
        }
    }

}

// MARK: - avatar button
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {

    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        authorAvatarButtonDidPressed button: AvatarButton
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            await DataSourceFacade.coordinateToProfileScene(
                provider: self,
                target: .status,
                status: status
            )
        }
    }

}

// MARK: - content
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        metaText: MetaText,
        didSelectMeta meta: Meta
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            
            try await DataSourceFacade.responseToMetaTextAction(
                provider: self,
                target: .status,
                status: status,
                meta: meta
            )
        }
    }

}

// MARK: - card
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {

    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        didTapCardWithURL url: URL
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }

            await DataSourceFacade.responseToURLAction(
                provider: self,
                status: status,
                url: url
            )
        }
    }

    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        cardControl: StatusCardControl,
        didTapURL url: URL
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }

            await DataSourceFacade.responseToURLAction(
                provider: self,
                status: status,
                url: url
            )
        }
    }

    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        cardControlMenu statusCardControl: StatusCardControl
    ) -> [LabeledAction]? {
        guard let card = statusView.viewModel.card,
              let url = URL(string: card.url) else {
            return nil
        }

        return [
            LabeledAction(
                title: L10n.Common.Controls.Actions.copy,
                image: UIImage(systemName: "doc.on.doc")
            ) {
                UIPasteboard.general.url = url
            },

            LabeledAction(
                title: L10n.Common.Controls.Actions.share,
                asset: Asset.Arrow.squareAndArrowUp
            ) {
                DispatchQueue.main.async {
                    let activityViewController = UIActivityViewController(
                        activityItems: [
                            URLActivityItemWithMetadata(url: url) { metadata in
                                metadata.title = card.title

                                if let image = card.image, let url = URL(string: image) {
                                    metadata.iconProvider = ImageProvider(url: url, filter: nil).itemProvider
                                }
                            }
                        ],
                        applicationActivities: []
                    )
                    self.coordinator.present(
                        scene: .activityViewController(
                            activityViewController: activityViewController,
                            sourceView: statusCardControl, barButtonItem: nil
                        ),
                        from: self,
                        transition: .activityViewControllerPresent(animated: true)
                    )
                }
            },

            LabeledAction(
                title: L10n.Common.Controls.Status.Actions.shareLinkInPost,
                image: UIImage(systemName: "square.and.pencil")
            ) {
                DispatchQueue.main.async {
                    self.coordinator.present(
                        scene: .compose(viewModel: ComposeViewModel(
                            context: self.context,
                            authContext: self.authContext,
                            composeContext: .composeStatus,
                            destination: .topLevel,
                            initialContent: L10n.Common.Controls.Status.linkViaUser(url.absoluteString, "@" + (statusView.viewModel.authorUsername ?? ""))
                        )),
                        from: self,
                        transition: .modal(animated: true)
                    )
                }
            }
        ]
    }

}

// MARK: - media
extension StatusTableViewCellDelegate where Self: DataSourceProvider & MediaPreviewableViewController {
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        mediaGridContainerView: MediaGridContainerView,
        mediaView: MediaView,
        didSelectMediaViewAt index: Int
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            
            let needsToggleMediaSensitive = await !statusView.viewModel.isMediaReveal
            
            guard !needsToggleMediaSensitive else {
                try await DataSourceFacade.responseToToggleSensitiveAction(
                    dependency: self,
                    status: status
                )
                return
            }
            
            try await DataSourceFacade.coordinateToMediaPreviewScene(
                dependency: self,
                status: status,
                previewContext: DataSourceFacade.AttachmentPreviewContext(
                    containerView: .mediaGridContainerView(mediaGridContainerView),
                    mediaView: mediaView,
                    index: index
                )
            )
        }   // end Task
    }

}


// MARK: - poll
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        pollTableView tableView: UITableView,
        didSelectRowAt indexPath: IndexPath
    ) {
        guard let pollTableViewDiffableDataSource = statusView.pollTableViewDiffableDataSource else { return }
        guard let pollItem = pollTableViewDiffableDataSource.itemIdentifier(for: indexPath) else { return }
                
        let managedObjectContext = context.managedObjectContext
        
        Task {
            guard case let .option(pollOption) = pollItem else {
                assertionFailure("only works for status data provider")
                return
            }
                     
//            var _poll: ManagedObjectRecord<Poll>?
//            var _isMultiple: Bool?
//            var _choice: Int?
//            
//            try await managedObjectContext.performChanges {
//                guard let pollOption = pollOption.object(in: managedObjectContext) else { return }
//                guard let poll = pollOption.poll else { return }
//                _poll = .init(objectID: poll.objectID)
//
//                _isMultiple = poll.multiple
//                guard !poll.isVoting else { return }
//                
//                if !poll.multiple {
//                    for option in poll.options where option != pollOption {
//                        option.update(isSelected: false)
//                    }
//                    
//                    // mark voting
//                    poll.update(isVoting: true)
//                    // set choice
//                    _choice = Int(pollOption.index)
//                }
//                
//                pollOption.update(isSelected: !pollOption.isSelected)
//                poll.update(updatedAt: Date())
//            }
            
            // Trigger vote API request for
            guard pollOption.poll.multiple == false else { return }

            do {
                _ = try await context.apiService.vote(
                    poll: pollOption.poll,
                    choices: [indexPath.row],
                    authenticationBox: authContext.mastodonAuthenticationBox
                )
            } catch {
                // restore voting state
//                try await managedObjectContext.performChanges {
//                    guard
//                        let pollOption = pollOption.object(in: managedObjectContext),
//                        let poll = pollOption.poll
//                    else { return }
//                    poll.update(isVoting: false)
//                }
            }
            
        }   // end Task
    }
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        pollVoteButtonPressed button: UIButton
    ) {
        guard let pollTableViewDiffableDataSource = statusView.pollTableViewDiffableDataSource else { return }
        guard let firstPollItem = pollTableViewDiffableDataSource.snapshot().itemIdentifiers.first else { return }
        guard case let .option(option, poll) = firstPollItem else { return }
        
        let managedObjectContext = context.managedObjectContext
        
        Task {
            // Trigger vote API request for
            
            assertionFailure("Re-implement this")
//            do {
//                _ = try await context.apiService.vote(
//                    poll: poll,
//                    choices: choices,
//                    authenticationBox: authContext.mastodonAuthenticationBox
//                )
//            } catch {
//                // restore voting state
//                try await managedObjectContext.performChanges {
//                    guard let poll = poll.object(in: managedObjectContext) else { return }
//                    poll.update(isVoting: false)
//                }
//            }
            
        }   // end Task
    }

}

// MARK: - toolbar
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        actionToolbarContainer: ActionToolbarContainer,
        buttonDidPressed button: UIButton,
        action: ActionToolbarContainer.Action
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            
            try await DataSourceFacade.responseToActionToolbar(
                provider: self,
                status: status,
                action: action,
                sender: button
            )
        }   // end Task
    }

}

// MARK: - menu button
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        menuButton button: UIButton,
        didSelectAction action: MastodonMenu.Action
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }

            if case .translateStatus = action {
                DispatchQueue.main.async {
                    if let cell = cell as? StatusTableViewCell {
                        cell.statusView.viewModel.isCurrentlyTranslating = true
                    } else if let cell = cell as? StatusThreadRootTableViewCell {
                        cell.statusView.viewModel.isCurrentlyTranslating = true
                    }
                    cell.invalidateIntrinsicContentSize()
                }
            }

            if case .showOriginal = action {
                DispatchQueue.main.async {
                    if let cell = cell as? StatusTableViewCell {
                        cell.statusView.revertTranslation()
                    }
                }
            }

            let statusViewModel: StatusView.ViewModel?

            if let cell = cell as? StatusTableViewCell {
                statusViewModel = await cell.statusView.viewModel
            } else if let cell = cell as? StatusThreadRootTableViewCell {
                statusViewModel = await cell.statusView.viewModel
            } else {
                statusViewModel = nil
            }

            try await DataSourceFacade.responseToMenuAction(
                dependency: self,
                action: action,
                menuContext: .init(
                    author: status.account,
                    statusViewModel: statusViewModel,
                    button: button,
                    barButtonItem: nil
                )
            )
        }   // end Task
    }

}

// MARK: - content warning
extension StatusTableViewCellDelegate where Self: DataSourceProvider {
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        contentSensitiveeToggleButtonDidPressed button: UIButton
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            try await DataSourceFacade.responseToToggleSensitiveAction(
                dependency: self,
                status: status
            )
        }   // end Task
    }
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        spoilerOverlayViewDidPressed overlayView: SpoilerOverlayView
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            try await DataSourceFacade.responseToToggleSensitiveAction(
                dependency: self,
                status: status
            )
        }   // end Task
    }
    
//    func tableViewCell(
//        _ cell: UITableViewCell,
//        statusView: StatusView,
//        spoilerBannerViewDidPressed bannerView: SpoilerBannerView
//    ) {
//        Task {
//            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
//            guard let item = await item(from: source) else {
//                assertionFailure()
//                return
//            }
//            guard case let .status(status) = item else {
//                assertionFailure("only works for status data provider")
//                return
//            }
//            try await DataSourceFacade.responseToToggleSensitiveAction(
//                dependency: self,
//                status: status
//            )
//        }   // end Task
//    }
    
    func tableViewCell(
        _ cell: UITableViewCell,
        statusView: StatusView,
        mediaGridContainerView: MediaGridContainerView,
        mediaSensitiveButtonDidPressed button: UIButton
    ) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            try await DataSourceFacade.responseToToggleSensitiveAction(
                dependency: self,
                status: status
            )
        }   // end Task
    }

}

// MARK: - StatusMetricView
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    func tableViewCell(_ cell: UITableViewCell, statusView: StatusView, statusMetricView: StatusMetricView, reblogButtonDidPressed button: UIButton) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            let userListViewModel = UserListViewModel(
                context: context,
                authContext: authContext,
                kind: .rebloggedBy(status: status)
            )
            _ = await coordinator.present(
                scene: .rebloggedBy(viewModel: userListViewModel),
                from: self,
                transition: .show
            )
        }   // end Task
    }
    
    func tableViewCell(_ cell: UITableViewCell, statusView: StatusView, statusMetricView: StatusMetricView, favoriteButtonDidPressed button: UIButton) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            guard case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }
            let userListViewModel = UserListViewModel(
                context: context,
                authContext: authContext,
                kind: .favoritedBy(status: status)
            )
            _ = await coordinator.present(
                scene: .favoritedBy(viewModel: userListViewModel),
                from: self,
                transition: .show
            )
        }   // end Task
    }

    func tableViewCell(_ cell: UITableViewCell, statusView: StatusView, statusMetricView: StatusMetricView, showEditHistory button: UIButton) {
        Task {
            
            await coordinator.showLoading()
            
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await self.item(from: source),
                  case let .status(status) = item else {
                assertionFailure("only works for status data provider")
                return
            }

            do {
                let edits = try await context.apiService.getHistory(forStatusID: status.id, authenticationBox: authContext.mastodonAuthenticationBox).value

                await coordinator.hideLoading()

                let viewModel = StatusEditHistoryViewModel(status: status, edits: edits, appContext: context, authContext: authContext)
                _ = await coordinator.present(scene: .editHistory(viewModel: viewModel), from: self, transition: .show)
            } catch {
                await coordinator.hideLoading()
            }
        }
    }
}

// MARK: a11y
extension StatusTableViewCellDelegate where Self: DataSourceProvider & AuthContextProvider {
    func tableViewCell(_ cell: UITableViewCell, statusView: StatusView, accessibilityActivate: Void) {
        Task {
            let source = DataSourceItem.Source(tableViewCell: cell, indexPath: nil)
            guard let item = await item(from: source) else {
                assertionFailure()
                return
            }
            switch item {
            case .status(let status):
                await DataSourceFacade.coordinateToStatusThreadScene(
                    provider: self,
                    target: .status,    // remove reblog wrapper
                    status: status
                )
            case .user(let user):
                await DataSourceFacade.coordinateToProfileScene(
                    provider: self,
                    user: user
                )
            case .notification:
                assertionFailure("TODO")
            default:
                assertionFailure("TODO")
            }
        }
    }
}
