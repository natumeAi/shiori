import Flutter
import UIKit
import Metal
import QuartzCore
import ObjectiveC.runtime
import Darwin

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var presentationChannel: FlutterMethodChannel?
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PresentationProbe") {
      let channel = FlutterMethodChannel(
        name: "io.github.natumeai.shiori/presentation_probe",
        binaryMessenger: registrar.messenger())
      // Registration alone must not instantiate buffers, inspect views, or install hooks.
      channel.setMethodCallHandler { call, result in
        PresentationProbeNative.shared.handle(call, result: result)
      }
      presentationChannel = channel
    }
  }
}

private struct PresentationSample {
  var kind = 0 // 1: layer_commit, 2: display_link, 3: drawable
  var timestamp = 0.0
  var targetTimestamp = 0.0
  var drawableID: UInt64 = 0
  var drawableAddress: UInt = 0
  var presentedTime = 0.0
  var generation: UInt64 = 0
}

// One process-wide hook owner. All shared state is guarded by lock. Hook writes
// only try the lock; contention is counted atomically instead of waiting.
private final class PresentationBuffer {
  static let sampleCapacity = 16384
  let capacity = PresentationBuffer.sampleCapacity
  private let lock = NSLock()
  private let entries: UnsafeMutablePointer<PresentationSample>
  private let lookup: UnsafeMutablePointer<Int>
  private var count = 0, head = 0, overflow = 0
  private var unmatchedCallbacks = 0
  private let contention: UnsafeMutablePointer<Int64>
  private var contentionStart: Int64 = 0
  private var generation: UInt64 = 0
  private var mode = "inventory"
  private weak var layer: CALayer?
  private var enabled = false

  init() {
    // Initialize local storage before assigning properties, without accessing
    // a partially initialized self.
    let size = PresentationBuffer.sampleCapacity
    let samples = UnsafeMutablePointer<PresentationSample>.allocate(capacity: size)
    samples.initialize(repeating: PresentationSample(), count: size)
    let indices = UnsafeMutablePointer<Int>.allocate(capacity: size)
    indices.initialize(repeating: -1, count: size)
    // Stable storage avoids concurrent Swift inout access to a stored property.
    let counter = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    counter.initialize(to: 0)
    entries = samples
    lookup = indices
    contention = counter
  }

  func begin(layer: CALayer?, mode: String, enabled: Bool) {
    lock.lock()
    defer { lock.unlock() }
    generation &+= 1
    self.layer = layer
    self.mode = mode
    self.enabled = enabled
    count = 0; head = 0; overflow = 0; unmatchedCallbacks = 0
    // Atomic snapshot: failed try-locks may still increment concurrently.
    contentionStart = OSAtomicAdd64Barrier(0, contention)
    for index in 0..<capacity { lookup[index] = -1 }
  }

  private func enter() -> Bool {
    if lock.try() { return true }
    OSAtomicIncrement64Barrier(contention)
    return false
  }

  private func append(_ sample: PresentationSample) -> Int {
    let index = (head + count) % capacity
    entries[index] = sample
    if count == capacity { head = (head + 1) % capacity; overflow += 1 }
    else { count += 1 }
    return index
  }

  func commit(_ object: AnyObject) {
    guard Thread.isMainThread, enter() else { return }
    defer { lock.unlock() }
    guard enabled, object === layer, mode == "a1" || mode == "a2" else { return }
    _ = append(PresentationSample(kind: 1, timestamp: CACurrentMediaTime()))
  }

  func display(_ link: CADisplayLink) {
    guard enter() else { return }
    defer { lock.unlock() }
    guard enabled, mode == "a2" else { return }
    _ = append(PresentationSample(
      kind: 2, timestamp: link.timestamp, targetTimestamp: link.targetTimestamp))
  }

  func acquired(_ drawable: CAMetalDrawable, from object: AnyObject) -> Bool {
    guard enter() else { return false }
    defer { lock.unlock() }
    guard enabled, mode == "b", object === layer else { return false }
    let id = UInt64(drawable.drawableID)
    let index = append(PresentationSample(
      kind: 3, timestamp: CACurrentMediaTime(), drawableID: id,
      drawableAddress: UInt(bitPattern: Unmanaged.passUnretained(drawable as AnyObject).toOpaque()),
      generation: generation))
    lookup[Int(id % UInt64(capacity))] = index
    return true
  }

  func presented(_ drawable: MTLDrawable) {
    guard enter() else { return }
    defer { lock.unlock() }
    guard enabled, mode == "b", let metal = drawable as? CAMetalDrawable,
          metal.layer === layer else { return }
    let id = UInt64(drawable.drawableID)
    let index = lookup[Int(id % UInt64(capacity))]
    guard index >= 0, entries[index].kind == 3, entries[index].drawableID == id,
          entries[index].drawableAddress == UInt(bitPattern: Unmanaged.passUnretained(drawable as AnyObject).toOpaque()),
          entries[index].generation == generation else { unmatchedCallbacks += 1; return }
    entries[index].presentedTime = drawable.presentedTime
  }

  func end() -> ([[String: Any]], Int, Int, Int) {
    lock.lock()
    enabled = false
    let lost = Int(OSAtomicAdd64Barrier(0, contention) - contentionStart)
    // Allocate/export only after disabling capture. No channel traffic per frame.
    var samples = [[String: Any]]()
    for offset in 0..<count {
      let s = entries[(head + offset) % capacity]
      switch s.kind {
      case 1: samples.append(["kind": "layer_commit", "timestamp": s.timestamp])
      case 2: samples.append([
        "kind": "display_link", "timestamp": s.timestamp,
        "targetTimestamp": s.targetTimestamp])
      default: samples.append([
        "kind": "drawable", "timestamp": s.timestamp,
        "drawableId": String(s.drawableID), "presentedTime": s.presentedTime])
      }
    }
    let evicted = overflow
    let unmatched = unmatchedCallbacks
    lock.unlock()
    return (samples, evicted + lost, lost, unmatched)
  }
}

private final class PresentationProbeNative: NSObject {
  static let shared = PresentationProbeNative()
  private var buffer: PresentationBuffer?
  private var installed = false
  private var mode = "inventory"
  private var runID = ""
  private var omission: String?
  private var inventory = [String: Any]()
  private var displayLink: CADisplayLink?
  private var contentsHook = false, drawableHook = false
  // Created once on install, reused for every drawable. No per-frame Swift
  // capture closures, sample dictionaries, dispatches, or channel calls.
  private var presentedBlock: AnyObject?
  private let addPresentedSelector = NSSelectorFromString("addPresentedHandler:")

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard Thread.isMainThread else {
      result(FlutterError(code: "thread", message: "Main thread required", details: nil))
      return
    }
    switch call.method {
    case "install":
      if !installed {
        buffer = PresentationBuffer()
        let handler: @convention(block) (AnyObject) -> Void = { [weak self] object in
          if let drawable = object as? MTLDrawable { self?.buffer?.presented(drawable) }
        }
        // Bridge/copy once, outside frame work. The IMP call below passes this
        // existing Objective-C block, avoiding a fresh Swift closure bridge.
        presentedBlock = unsafeBitCast(handler, to: AnyObject.self)
        installed = true
      }
      // install is idempotent and never resets an active run. Hooks are installed
      // lazily by start, once the actual FlutterView layer can be checked.
      let layer = flutterLayer()
      readInventory(layer)
      var initial = report(samples: [], overflow: 0)
      initial["mode"] = "inventory"; initial["evidence"] = "metadata"
      initial["available"] = layer != nil
      if layer == nil { initial["omission"] = "flutter_view_layer_unavailable" }
      else { initial["omission"] = NSNull() }
      result(initial)
    case "start":
      guard installed, let args = call.arguments as? [String: Any],
            let id = args["runId"] as? String, !id.isEmpty,
            let requested = args["mode"] as? String,
            ["inventory", "a1", "a2", "b"].contains(requested) else {
        result(FlutterError(code: "arguments", message: "Install and valid run/mode required", details: nil))
        return
      }
      displayLink?.invalidate(); displayLink = nil
      _ = buffer?.end()
      mode = requested; runID = id
      let layer = flutterLayer()
      readInventory(layer)
      omission = nil
      if let layer = layer {
        if mode == "a1" || mode == "a2" {
          if let cls = NSClassFromString("FlutterMetalLayer"), type(of: layer) == cls {
            if !hookContents(cls) { omission = "setContents_hook_unavailable" }
          } else { omission = "requires_FlutterMetalLayer" }
        } else if mode == "b" {
          if type(of: layer) == CAMetalLayer.self,
             Bundle.main.object(forInfoDictionaryKey: "FLTUseFlutterMetalLayer") as? Bool == false {
            if !hookDrawable() { omission = "nextDrawable_hook_unavailable" }
          } else { omission = "requires_cametal_variant" }
        }
      } else { omission = "flutter_view_layer_unavailable" }
      buffer?.begin(layer: layer, mode: mode, enabled: omission == nil && mode != "inventory")
      if mode == "a2" && omission == nil {
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        link.add(to: .main, forMode: .common)
        displayLink = link
      }
      result(nil)
    case "stop":
      displayLink?.invalidate(); displayLink = nil
      let snapshot = buffer?.end() ?? ([], 0, 0, 0)
      if omission == nil && mode != "inventory" && snapshot.0.isEmpty {
        omission = "no_native_samples"
      }
      if omission == nil && mode == "a2" {
        if !snapshot.0.contains(where: { $0["kind"] as? String == "layer_commit" }) {
          omission = "no_layer_commit_samples"
        } else if !snapshot.0.contains(where: { $0["kind"] as? String == "display_link" }) {
          omission = "no_display_link_samples"
        }
      }
      if omission == nil && mode == "b" &&
          !snapshot.0.contains(where: { ($0["presentedTime"] as? Double ?? 0) > 0 }) {
        omission = "no_presented_drawables_at_stop"
      }
      result(report(samples: snapshot.0, overflow: snapshot.1,
                    contention: snapshot.2, unmatched: snapshot.3))
    case "dispose":
      displayLink?.invalidate(); displayLink = nil
      _ = buffer?.end()
      // Keep the preallocated buffer and shared callback alive for late callbacks
      // and permanent swizzles. Reinstall does not replace their storage.
      result(nil)
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func flutterLayer() -> CALayer? {
    func find(_ view: UIView) -> CALayer? {
      if NSStringFromClass(type(of: view)) == "FlutterView" { return view.layer }
      for child in view.subviews { if let layer = find(child) { return layer } }
      return nil
    }
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows where window.isKeyWindow {
        if let layer = find(window) { return layer }
      }
    }
    return nil
  }

  private func readInventory(_ layer: CALayer?) {
    inventory = [
      "layerClass": layer.map { NSStringFromClass(type(of: $0)) } ?? "unavailable",
      "FLTUseFlutterMetalLayer": Bundle.main.object(forInfoDictionaryKey: "FLTUseFlutterMetalLayer") ?? NSNull(),
      "maximumFramesPerSecond": UIScreen.main.maximumFramesPerSecond,
      "lowPowerMode": ProcessInfo.processInfo.isLowPowerModeEnabled,
      "thermalState": ProcessInfo.processInfo.thermalState.rawValue,
      "iosVersion": UIDevice.current.systemVersion,
      "ringCapacity": PresentationBuffer.sampleCapacity,
    ]
  }

  private func report(samples: [[String: Any]], overflow: Int,
                      contention: Int = 0, unmatched: Int = 0) -> [String: Any] {
    let evidence: String
    switch mode {
    case "a1": evidence = "layer_commit_cadence"
    case "a2": evidence = "layer_commit_cadence_per_display_period"
    case "b": evidence = "system_drawable_presentation_non_product_path"
    default: evidence = "metadata"
    }
    return [
      "available": omission == nil, "mode": mode, "runId": runID,
      "evidence": evidence, "omission": omission as Any? ?? NSNull(),
      "inventory": inventory, "samples": samples, "overflow": overflow,
      "contentionDrops": contention,
      "unmatchedCallbacks": unmatched,
    ]
  }

  @objc private func tick(_ link: CADisplayLink) { buffer?.display(link) }

  private func hookContents(_ cls: AnyClass) -> Bool {
    if contentsHook { return true }
    let selector = NSSelectorFromString("setContents:")
    guard let method = class_getInstanceMethod(cls, selector) else { return false }
    typealias Original = @convention(c) (AnyObject, Selector, AnyObject?) -> Void
    let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
    let hook: @convention(block) (AnyObject, AnyObject?) -> Void = { [self] object, contents in
      buffer?.commit(object)
      original(object, selector, contents)
    }
    let replacement = imp_implementationWithBlock(hook)
    // setContents: is inherited from CALayer in the pin. Add an override only
    // on FlutterMetalLayer; never replace the inherited CALayer implementation.
    guard class_addMethod(cls, selector, replacement, method_getTypeEncoding(method)) else {
      imp_removeBlock(replacement)
      return false
    }
    contentsHook = true
    return true
  }

  private func hookDrawable() -> Bool {
    if drawableHook { return true }
    let selector = #selector(CAMetalLayer.nextDrawable)
    guard let method = class_getInstanceMethod(CAMetalLayer.self, selector) else { return false }
    // Objective-C returns an autoreleased protocol object. Preserve +0 ownership
    // across the C IMP call and bridge it to a strong local before using it.
    typealias Original = @convention(c) (AnyObject, Selector) -> Unmanaged<AnyObject>?
    let original = unsafeBitCast(method_getImplementation(method), to: Original.self)
    let hook: @convention(block) (AnyObject) -> AnyObject? = { [self] object in
      let value = original(object, selector)?.takeUnretainedValue()
      if let drawable = value as? CAMetalDrawable,
         buffer?.acquired(drawable, from: object) == true,
         let handler = presentedBlock, let cls = object_getClass(drawable) {
        if let addMethod = class_getInstanceMethod(cls, addPresentedSelector) {
          // Public Metal API; id and block have the same object-pointer ABI.
          typealias AddHandler = @convention(c) (AnyObject, Selector, AnyObject) -> Void
          let add = unsafeBitCast(method_getImplementation(addMethod), to: AddHandler.self)
          add(drawable, addPresentedSelector, handler)
        }
      }
      return value
    }
    method_setImplementation(method, imp_implementationWithBlock(hook))
    drawableHook = true
    return true
  }
}
