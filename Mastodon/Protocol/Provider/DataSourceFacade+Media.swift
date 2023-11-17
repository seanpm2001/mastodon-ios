//
//  DataSourceFacade+Media.swift
//  Mastodon
//
//  Created by MainasuK on 2022-1-26.
//

import UIKit
import MastodonUI
import MastodonLocalization
import MastodonSDK

extension DataSourceFacade {
    
    @MainActor
    static func coordinateToMediaPreviewScene(
        dependency: NeedsDependency & MediaPreviewableViewController,
        mediaPreviewItem: MediaPreviewViewModel.PreviewItem,
        mediaPreviewTransitionItem: MediaPreviewTransitionItem
    ) {
        let mediaPreviewViewModel = MediaPreviewViewModel(
            context: dependency.context,
            item: mediaPreviewItem,
            transitionItem: mediaPreviewTransitionItem
        )
        _ = dependency.coordinator.present(
            scene: .mediaPreview(viewModel: mediaPreviewViewModel),
            from: dependency,
            transition: .custom(transitioningDelegate: dependency.mediaPreviewTransitionController)
        )
    }
    
}

extension DataSourceFacade {
    
    struct AttachmentPreviewContext {
        let containerView: ContainerView
        let mediaView: MediaView
        let index: Int
        
        enum ContainerView {
            case mediaView(MediaView)
            case mediaGridContainerView(MediaGridContainerView)
        }
        
        func thumbnails() async -> [UIImage?] {
            switch containerView {
            case .mediaView(let mediaView):
                let thumbnail = await mediaView.thumbnail()
                return [thumbnail]
            case .mediaGridContainerView(let mediaGridContainerView):
                let thumbnails = await mediaGridContainerView.mediaViews.parallelMap { mediaView in
                    return await mediaView.thumbnail()
                }
                return thumbnails
            }
        }
    }
    
    @MainActor
    static func coordinateToMediaPreviewScene(
        dependency: NeedsDependency & MediaPreviewableViewController,
        status: Mastodon.Entity.Status,
        previewContext: AttachmentPreviewContext
    ) async throws {
        let managedObjectContext = dependency.context.managedObjectContext
        let status = status.reblog ?? status
        let attachments = status.mastodonAttachments
        
        let thumbnails = await previewContext.thumbnails()
        
        let _source: MediaPreviewTransitionItem.Source? = {
            switch previewContext.containerView {
            case .mediaView(let mediaView):
                return .attachment(mediaView)
            case .mediaGridContainerView(let mediaGridContainerView):
                return .attachments(mediaGridContainerView)
            }
        }()
        guard let source = _source else {
            return
        }
        
        let mediaPreviewTransitionItem: MediaPreviewTransitionItem = {
            let item = MediaPreviewTransitionItem(
                source: source,
                previewableViewController: dependency
            )
            
            let mediaView = previewContext.mediaView

            item.initialFrame = {
                let initialFrame = mediaView.superview!.convert(mediaView.frame, to: nil)
                assert(initialFrame != .zero)
                return initialFrame
            }()
            
            let thumbnail = mediaView.thumbnail()
            item.image = thumbnail
            
            item.aspectRatio = {
                if let thumbnail = thumbnail {
                    return thumbnail.size
                }
                let index = previewContext.index
                guard index < attachments.count else { return nil }
                let size = attachments[index].size
                return size
            }()
            
            return item
        }()
        
        
        let mediaPreviewItem = MediaPreviewViewModel.PreviewItem.attachment(.init(
            attachments: attachments,
            initialIndex: previewContext.index,
            thumbnails: thumbnails
        ))
        
        coordinateToMediaPreviewScene(
            dependency: dependency,
            mediaPreviewItem: mediaPreviewItem,
            mediaPreviewTransitionItem: mediaPreviewTransitionItem
        )
    }
    
}

extension DataSourceFacade {
    
    struct ImagePreviewContext {
        let imageView: UIImageView
        let containerView: ContainerView
        
        enum ContainerView {
            case profileAvatar(ProfileHeaderView)
            case profileBanner(ProfileHeaderView)
        }
        
        func thumbnail() async -> UIImage? {
            return await imageView.image
        }
    }
    
    @MainActor
    static func coordinateToMediaPreviewScene(
        dependency: NeedsDependency & MediaPreviewableViewController,
        user: Mastodon.Entity.Account,
        previewContext: ImagePreviewContext
    ) async throws {
        let managedObjectContext = dependency.context.managedObjectContext
        
        var _avatarAssetURL: String? = user.avatar
        var _headerAssetURL: String? = user.header

        let thumbnail = await previewContext.thumbnail()
        
        let source: MediaPreviewTransitionItem.Source = {
            switch previewContext.containerView {
            case .profileAvatar(let view):      return .profileAvatar(view)
            case .profileBanner(let view):      return .profileBanner(view)
            }
        }()
        
        let mediaPreviewTransitionItem: MediaPreviewTransitionItem = {
            let item = MediaPreviewTransitionItem(
                source: source,
                previewableViewController: dependency
            )
            
            let imageView = previewContext.imageView
            item.initialFrame = {
                let initialFrame = imageView.superview!.convert(imageView.frame, to: nil)
                assert(initialFrame != .zero)
                return initialFrame
            }()
            
            item.image = thumbnail
            
            item.aspectRatio = {
                if let thumbnail = thumbnail {
                    return thumbnail.size
                }
                return CGSize(width: 100, height: 100)
            }()
            
            item.sourceImageViewCornerRadius = {
                switch previewContext.containerView {
                case .profileAvatar:
                    return ProfileHeaderView.avatarImageViewCornerRadius
                case .profileBanner:
                    return 0
                }
            }()
            
            return item
        }()
        
        
        let mediaPreviewItem: MediaPreviewViewModel.PreviewItem = {
            switch previewContext.containerView {
            case .profileAvatar:
                return .profileAvatar(.init(
                    assetURL: _avatarAssetURL,
                    thumbnail: thumbnail
                ))
            case .profileBanner:
                return .profileBanner(.init(
                    assetURL: _headerAssetURL,
                    thumbnail: thumbnail
                ))
            }
        }()
        
        guard mediaPreviewItem.isAssetURLValid else {
            return
        }
        
        coordinateToMediaPreviewScene(
            dependency: dependency,
            mediaPreviewItem: mediaPreviewItem,
            mediaPreviewTransitionItem: mediaPreviewTransitionItem
        )
    }

}
