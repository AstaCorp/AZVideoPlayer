//
//  AZPlayerContainer.swift
//  AZVideoPlayer
//
//  Created by Stanislav Marynych on 15.09.2025.
//

import SwiftUI
import AVKit

public struct AZVideoPlayerContainer: UIViewRepresentable {
    public typealias TransitionCompletion = AZVideoPlayerDelegate.TransitionCompletion
    public typealias StatusDidChange = AZVideoPlayerDelegate.StatusDidChange

    private let delegate: AZVideoPlayerDelegate

    public init(
        player: AVPlayer?,
        willBeginFullScreenPresentationWithAnimationCoordinator: TransitionCompletion? = nil,
        willEndFullScreenPresentationWithAnimationCoordinator: TransitionCompletion? = nil,
        statusDidChange: StatusDidChange? = nil,
        showsPlaybackControls: Bool = true,
        entersFullScreenWhenPlaybackBegins: Bool = false,
        pausesWhenFullScreenPlaybackEnds: Bool = false
    ) {
        self.delegate = AZVideoPlayerDelegate(
            player: player,
            willBeginFullScreen: willBeginFullScreenPresentationWithAnimationCoordinator,
            willEndFullScreen: willEndFullScreenPresentationWithAnimationCoordinator,
            statusDidChange: statusDidChange,
            showsPlaybackControls: showsPlaybackControls,
            entersFullScreenWhenPlaybackBegins: entersFullScreenWhenPlaybackBegins,
            pausesWhenFullScreenPlaybackEnds: pausesWhenFullScreenPlaybackEnds
        )
    }

    public func makeUIView(context: Context) -> UIView {
        delegate.controller.view
    }

    public func updateUIView(_ uiView: UIView, context: Context) {
        delegate.controller.player = delegate.player
    }
}
