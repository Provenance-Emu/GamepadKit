import GameController

/// D-pad-as-stick: what the wrapper does with the D-pad when
/// ``PhysicalProfileConfiguration/dpadStick`` is set.
extension PhysicalProfileController {
    /// The physical D-pad moved (only called when D-pad-as-stick is configured).
    func dpadChanged(x: Float, y: Float) {
        let previousY = rawDpad.y
        rawDpad = (x, y)
        if let chord = configuration.dpadStick?.modeChord, tracker.isHeld(chord) {
            // Chord held: up / down pick the mode, and the game sees a D-pad at rest.
            let threshold = DpadStickEmulator.pressThreshold
            if y > threshold, previousY <= threshold {
                selectTap.cancel()
                setDpadMode(storedDpadMode.cycled(forward: true))
            } else if y < -threshold, previousY >= -threshold {
                selectTap.cancel()
                setDpadMode(storedDpadMode.cycled(forward: false))
            } else {
                applyDpad()
            }
            return
        }
        applyDpad()
    }

    func setDpadMode(_ mode: DpadMode) {
        guard configuration.dpadStick != nil, mode != storedDpadMode else { return }
        storedDpadMode = mode
        configuration.log?(.info, "PhysicalProfileController[\(pad.rawValue)]: D-pad mode \(mode.rawValue)")
        applyDpad()
        onDpadModeChanged?(mode)
    }

    /// Sends the D-pad's position to whatever the mode says it drives.
    func applyDpad() {
        var position = rawDpad
        if let chord = configuration.dpadStick?.modeChord, tracker.isHeld(chord) { position = (0, 0) }
        let rest: (x: Float, y: Float) = (0, 0)
        let dpadPosition = storedDpadMode.drivesDpad ? position : rest
        if synthesized.synthesizedDpad.update(x: dpadPosition.x, y: dpadPosition.y) {
            synthesized.notify(synthesized.synthesizedDpad)
        }
        let wasActive = dpadEmulator.isActive
        let stickPosition = storedDpadMode.drivesStick ? position : rest
        dpadEmulator.setDirection(x: stickPosition.x, y: stickPosition.y, at: clock())
        // At rest the emulated stick writes once (to centre) and then leaves the
        // element alone, so a pad that also has a real stick keeps it.
        if wasActive || dpadEmulator.isActive { refreshEmulatedStick() }
    }

    /// Writes the emulated stick for the current time, and keeps a timer running
    /// while a ramp is still moving it.
    func refreshEmulatedStick() {
        guard configuration.dpadStick != nil, storedDpadMode.drivesStick || dpadEmulator.isActive else { return }
        let now = clock()
        let modifierHeld = configuration.dpadStick?.modifier.map { tracker.isHeld($0) } ?? false
        let stick = dpadEmulator.stick(at: now, modifierHeld: modifierHeld)
        if synthesized.synthesizedLeftThumbstick.update(x: stick.x, y: stick.y) {
            synthesized.notify(synthesized.synthesizedLeftThumbstick)
        }
        if dpadEmulator.isRamping(at: now) { startRampTimer() } else { stopRampTimer() }
    }

    /// Advances a ramp in progress. The wrapper calls this itself from a timer on the
    /// pad's handler queue; an app that would rather drive it from its frame loop can
    /// call it too.
    public func tick() {
        guard dpadEmulator.isActive else {
            stopRampTimer()
            return
        }
        refreshEmulatedStick()
    }

    private func startRampTimer() {
        guard rampTimer == nil else { return }
        let timer = DispatchSource.makeTimerSource(queue: base.handlerQueue)
        timer.schedule(deadline: .now() + .milliseconds(8), repeating: .milliseconds(8), leeway: .milliseconds(2))
        timer.setEventHandler { [weak self] in self?.tick() }
        rampTimer = timer
        timer.resume()
    }

    func stopRampTimer() {
        rampTimer?.cancel()
        rampTimer = nil
    }
}
