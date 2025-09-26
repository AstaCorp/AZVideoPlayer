//
//  AZVideoPlayerDelegate.swift
//  AZVideoPlayer
//
//  Created by Stanislav Marynych on 15.09.2025.
//

import UIKit
import AVKit

public final class AZVideoPlayerDelegate: NSObject, AVPlayerViewControllerDelegate {
    public typealias TransitionCompletion = (AVPlayerViewController, UIViewControllerTransitionCoordinator) -> Void
    public typealias StatusDidChange = (AZVideoPlayerStatus) -> Void

    var controller: AVPlayerViewController?
    weak var player: AVPlayer?

    private let willBeginFullScreen: TransitionCompletion?
    private let willEndFullScreen: TransitionCompletion?
    private let statusDidChange: StatusDidChange?
    private let pausesWhenFullScreenPlaybackEnds: Bool
    private let entersFullScreenWhenPlaybackBegins: Bool

    private var timeControlStatusObservation: NSKeyValueObservation?
    private var shouldEnterFullScreenPresentationOnNextPlay = true

    init(
        player: AVPlayer?,
        willBeginFullScreen: TransitionCompletion?,
        willEndFullScreen: TransitionCompletion?,
        statusDidChange: StatusDidChange?,
        showsPlaybackControls: Bool,
        entersFullScreenWhenPlaybackBegins: Bool,
        pausesWhenFullScreenPlaybackEnds: Bool
    ) {
        self.player = player
        self.willBeginFullScreen = willBeginFullScreen
        self.willEndFullScreen = willEndFullScreen
        self.statusDidChange = statusDidChange
        self.pausesWhenFullScreenPlaybackEnds = pausesWhenFullScreenPlaybackEnds
        self.entersFullScreenWhenPlaybackBegins = entersFullScreenWhenPlaybackBegins

        super.init()
    }

    // MARK: AVPlayerViewControllerDelegate
    
    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        willBeginFullScreen?(playerViewController, coordinator)
    }

    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        if !pausesWhenFullScreenPlaybackEnds {
            continuePlayingIfPlaying(player, coordinator)
        }
        
        willEndFullScreen?(playerViewController, coordinator)
    }
    
    public func configureController(showsPlaybackControls: Bool) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.entersFullScreenWhenPlaybackBegins = entersFullScreenWhenPlaybackBegins
        controller.videoGravity = .resizeAspectFill
        controller.delegate = self
        
        self.controller = controller

        forceShowControls(true)
        observePlayer(player)
        
        return controller
    }

    private func observePlayer(_ player: AVPlayer?) {
        guard let player else { return }
        timeControlStatusObservation = player.observe(\.timeControlStatus, changeHandler: { [weak self] player, _ in
            guard let self else { return }

            statusDidChange?(AZVideoPlayerStatus(
                timeControlStatus: player.timeControlStatus,
                volume: player.volume
            ))

            forceShowControls(player.timeControlStatus == .paused)

            if shouldEnterFullScreenPresentation(of: player) {
                controller?.enterFullScreenPresentation(animated: true)
            } else if player.timeControlStatus == .playing {
                shouldEnterFullScreenPresentationOnNextPlay = true
            }
        })
    }

    private func shouldEnterFullScreenPresentation(of player: AVPlayer) -> Bool {
        guard entersFullScreenWhenPlaybackBegins else { return false }
        return player.timeControlStatus == .playing && shouldEnterFullScreenPresentationOnNextPlay
    }

    private func continuePlayingIfPlaying(
        _ player: AVPlayer?,
        _ coordinator: UIViewControllerTransitionCoordinator
    ) {
        let isPlaying = player?.timeControlStatus == .playing

        coordinator.animate(alongsideTransition: nil) { _ in
            if isPlaying {
                self.shouldEnterFullScreenPresentationOnNextPlay = false
                player?.play()
            }
        }
    }

    private func forceShowControls(_ show: Bool) {
        controller?.setValue(!show, forKey: "canHidePlaybackControls")
    }
}
