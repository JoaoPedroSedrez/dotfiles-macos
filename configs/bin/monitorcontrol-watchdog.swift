// managed by ~/dotfiles — compiled and run by configs/bin/monitorcontrol-watchdog
//
// Restarts MonitorControl whenever a display (re)connects or the Mac wakes.
// On Apple Silicon, power-cycling the monitor or waking from sleep recreates
// its video service and MonitorControl keeps talking to the dead one, so
// brightness keys silently stop working until the app is relaunched.
// Run by the launchd agent in configs/nix-darwin/macos.nix.
import AppKit

let bundleID = "app.monitorcontrol.MonitorControl"
let appURL = URL(fileURLWithPath: "/Applications/MonitorControl.app")

var pending: DispatchWorkItem?

// Displays fire several events in a burst while they come up; wait for them
// to settle and restart only once.
func scheduleRestart(_ reason: String) {
  pending?.cancel()
  let work = DispatchWorkItem { restart(reason) }
  pending = work
  DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
}

func restart(_ reason: String) {
  print("\(Date()) restarting MonitorControl: \(reason)")
  for app in NSRunningApplication.runningApplications(withBundleIdentifier: bundleID) {
    app.terminate()
    // Give it a moment to quit cleanly before forcing it.
    for _ in 0..<20 where !app.isTerminated {
      RunLoop.current.run(until: Date() + 0.1)
    }
    if !app.isTerminated { app.forceTerminate() }
  }
  let config = NSWorkspace.OpenConfiguration()
  config.activates = false
  NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
    if let error { print("\(Date()) failed to launch MonitorControl: \(error)") }
  }
}

CGDisplayRegisterReconfigurationCallback({ _, flags, _ in
  if flags.contains(.addFlag) { scheduleRestart("display connected") }
}, nil)

let center = NSWorkspace.shared.notificationCenter
for name in [NSWorkspace.didWakeNotification, NSWorkspace.screensDidWakeNotification] {
  center.addObserver(forName: name, object: nil, queue: .main) { note in
    scheduleRestart(note.name.rawValue)
  }
}

setvbuf(stdout, nil, _IOLBF, 0)
print("\(Date()) watching for display reconnects and wake")
RunLoop.main.run()
