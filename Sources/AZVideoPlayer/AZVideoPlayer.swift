//
//  AZVideoPlayer.swift
//  AZVideoPlayer
//
//  Created by Stanislav Marynych on 25.12.2025.
//

import SwiftUI
import AVKit

// MARK: - AZVideoPlayer

public struct AZVideoPlayer: UIViewControllerRepresentable {
    public typealias TransitionCompletion = AZVideoPlayerDelegate.TransitionCompletion
    public typealias StatusDidChange = AZVideoPlayerDelegate.StatusDidChange

    private let player: AVPlayer?
    private let willBeginFullScreen: TransitionCompletion?
    private let willEndFullScreen: TransitionCompletion?
    private let statusDidChange: StatusDidChange?
    private let showsPlaybackControls: Bool
    private let entersFullScreenWhenPlaybackBegins: Bool
    private let pausesWhenFullScreenPlaybackEnds: Bool

    public init(
        player: AVPlayer?,
        willBeginFullScreenPresentationWithAnimationCoordinator: TransitionCompletion? = nil,
        willEndFullScreenPresentationWithAnimationCoordinator: TransitionCompletion? = nil,
        statusDidChange: StatusDidChange? = nil,
        showsPlaybackControls: Bool = true,
        entersFullScreenWhenPlaybackBegins: Bool = false,
        pausesWhenFullScreenPlaybackEnds: Bool = false
    ) {
        self.player = player
        self.willBeginFullScreen = willBeginFullScreenPresentationWithAnimationCoordinator
        self.willEndFullScreen = willEndFullScreenPresentationWithAnimationCoordinator
        self.statusDidChange = statusDidChange
        self.showsPlaybackControls = showsPlaybackControls
        self.entersFullScreenWhenPlaybackBegins = entersFullScreenWhenPlaybackBegins
        self.pausesWhenFullScreenPlaybackEnds = pausesWhenFullScreenPlaybackEnds
    }

    public func makeUIViewController(context: Context) -> AVPlayerViewController {
        context.coordinator.delegate.configureController(showsPlaybackControls: showsPlaybackControls)
    }

    public func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        let coordinator = context.coordinator
        
        coordinator.delegate.updatePlayer(player)
        
        uiViewController.showsPlaybackControls = showsPlaybackControls
        uiViewController.entersFullScreenWhenPlaybackBegins = entersFullScreenWhenPlaybackBegins
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(
            player: player,
            willBeginFullScreen: willBeginFullScreen,
            willEndFullScreen: willEndFullScreen,
            statusDidChange: statusDidChange,
            showsPlaybackControls: showsPlaybackControls,
            entersFullScreenWhenPlaybackBegins: entersFullScreenWhenPlaybackBegins,
            pausesWhenFullScreenPlaybackEnds: pausesWhenFullScreenPlaybackEnds
        )
    }
    
    public class Coordinator {
        let delegate: AZVideoPlayerDelegate
        
        init(
            player: AVPlayer?,
            willBeginFullScreen: TransitionCompletion?,
            willEndFullScreen: TransitionCompletion?,
            statusDidChange: StatusDidChange?,
            showsPlaybackControls: Bool,
            entersFullScreenWhenPlaybackBegins: Bool,
            pausesWhenFullScreenPlaybackEnds: Bool
        ) {
            self.delegate = AZVideoPlayerDelegate(
                player: player,
                willBeginFullScreen: willBeginFullScreen,
                willEndFullScreen: willEndFullScreen,
                statusDidChange: statusDidChange,
                showsPlaybackControls: showsPlaybackControls,
                entersFullScreenWhenPlaybackBegins: entersFullScreenWhenPlaybackBegins,
                pausesWhenFullScreenPlaybackEnds: pausesWhenFullScreenPlaybackEnds
            )
        }
    }
}

// MARK: - AZVideoPlayerDelegate

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
    private var playerItemStatusObservation: NSKeyValueObservation?
    private var shouldEnterFullScreenPresentationOnNextPlay = true
    private var isFullScreen: Bool = false
    private var hasEnteredFullScreenOnce = false
    
    private var isControllerInWindow: Bool {
        controller?.view.window != nil
    }
    
    private var isPlayerReady: Bool {
        guard let player = player,
              let currentItem = player.currentItem else {
            return false
        }
        return currentItem.status == .readyToPlay
    }

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
    
    deinit {
        invalidateSubscriptions()
    }

    // MARK: AVPlayerViewControllerDelegate
    
    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willBeginFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        isFullScreen = true
        hasEnteredFullScreenOnce = true
        shouldEnterFullScreenPresentationOnNextPlay = false
        
        willBeginFullScreen?(playerViewController, coordinator)
    }

    public func playerViewController(
        _ playerViewController: AVPlayerViewController,
        willEndFullScreenPresentationWithAnimationCoordinator coordinator: UIViewControllerTransitionCoordinator
    ) {
        isFullScreen = false
        
        if entersFullScreenWhenPlaybackBegins {
            shouldEnterFullScreenPresentationOnNextPlay = true
        }
        
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
    
    func updatePlayer(_ newPlayer: AVPlayer?) {
        guard player !== newPlayer else { return }
        
        invalidateSubscriptions()
        
        player = newPlayer
        controller?.player = newPlayer
        
        shouldEnterFullScreenPresentationOnNextPlay = true
        hasEnteredFullScreenOnce = false
        
        observePlayer(newPlayer)
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
                attemptFullScreenPresentation()
            }
        })
        
        if let currentItem = player.currentItem {
            playerItemStatusObservation = currentItem.observe(\.status, changeHandler: { [weak self] item, _ in
                guard let self else { return }
                
                if item.status == .readyToPlay, shouldEnterFullScreenPresentation(of: player) {
                    attemptFullScreenPresentation()
                }
            })
        }
    }
    
    private func invalidateSubscriptions() {
        timeControlStatusObservation?.invalidate()
        timeControlStatusObservation = nil
        playerItemStatusObservation?.invalidate()
        playerItemStatusObservation = nil
    }
    
    private func attemptFullScreenPresentation() {
        guard
            shouldEnterFullScreenPresentationOnNextPlay,
            isPlayerReady,
            isControllerInWindow,
            !isFullScreen
        else {
            return
        }
        
        DispatchQueue.main.async {
            self.controller?.enterFullScreenPresentation(animated: true)
        }
    }

    private func shouldEnterFullScreenPresentation(of player: AVPlayer) -> Bool {
        guard entersFullScreenWhenPlaybackBegins, !isFullScreen else {
            return false
        }
        
        return player.timeControlStatus == .playing && shouldEnterFullScreenPresentationOnNextPlay
    }

    private func continuePlayingIfPlaying(
        _ player: AVPlayer?,
        _ coordinator: UIViewControllerTransitionCoordinator
    ) {
        let isPlaying = player?.timeControlStatus == .playing

        coordinator.animate(alongsideTransition: nil) { _ in
            if isPlaying {
                player?.play()
            }
        }
    }

    private func forceShowControls(_ show: Bool) {
        guard let controller else { return }
        
        let selectorName = "canHidePlaybackControls"
        
        if controller.responds(to: Selector(selectorName)) {
            controller.setValue(!show, forKey: selectorName)
        }
    }
}

// MARK: - AZVideoPlayerStatus

public struct AZVideoPlayerStatus {
    public let timeControlStatus: AVPlayer.TimeControlStatus
    public let volume: Float
}

// MARK: - AVPlayerViewController Extensions

extension AVPlayerViewController {
    func enterFullScreenPresentation(animated: Bool) {
        let selector = NSSelectorFromString("enterFullScreenAnimated:completionHandler:")
        guard responds(to: selector) else {
            print("⚠️ enterFullScreenAnimated:completionHandler: not available")
            return
        }
        perform(selector, with: animated, with: nil)
    }
    
    func exitFullScreenPresentation(animated: Bool) {
        let selector = NSSelectorFromString("exitFullScreenAnimated:completionHandler:")
        guard responds(to: selector) else {
            print("⚠️ exitFullScreenAnimated:completionHandler: not available")
            return
        }
        perform(selector, with: animated, with: nil)
    }
}
