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

    let controller: AVPlayerViewController
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

        self.controller = AVPlayerViewController()
        super.init()

        configureController(showsPlaybackControls: showsPlaybackControls)
        observePlayer(player)
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
    
    private func configureController(showsPlaybackControls: Bool) {
        controller.player = player
        controller.showsPlaybackControls = showsPlaybackControls
        controller.entersFullScreenWhenPlaybackBegins = entersFullScreenWhenPlaybackBegins
        controller.videoGravity = .resizeAspectFill
        controller.delegate = self

        // Force controls to show initially
        forceShowControls(true)
    }

    private func observePlayer(_ player: AVPlayer?) {
        guard let player else { return }
        timeControlStatusObservation = player.observe(\.timeControlStatus, changeHandler: { [weak self] player, _ in
            guard let self else { return }

            self.statusDidChange?(AZVideoPlayerStatus(
                timeControlStatus: player.timeControlStatus,
                volume: player.volume
            ))

            self.forceShowControls(player.timeControlStatus == .paused)

            if self.shouldEnterFullScreenPresentation(of: player) {
                self.controller.enterFullScreenPresentation(animated: true)
            } else if player.timeControlStatus == .playing {
                self.shouldEnterFullScreenPresentationOnNextPlay = true
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
        controller.setValue(!show, forKey: "canHidePlaybackControls")
    }
}
