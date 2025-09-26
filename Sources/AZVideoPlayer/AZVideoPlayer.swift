//
//  AZVideoPlayer.swift
//  AZVideoPlayer
//
//  Created by Adam Zarn on 7/4/22.
//

import SwiftUI
import AVKit

public struct AZVideoPlayer: UIViewControllerRepresentable {
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

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        delegate.controller
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}
