import SpriteKit
import SwiftUI
import UIKit
import WhaleyCore
import WhaleyObjectiveC
import WhaleySpriteKit

struct SrcWhaleyView: UIViewRepresentable {
    var designerProjection: ((CGPoint, SrcWhaleySKView) -> Void)? = nil

    func makeUIView(context: Context) -> SrcWhaleySKView {
        let view = SrcWhaleySKView(frame: .zero)
        view.backgroundColor = .black
        view.ignoresSiblingOrder = true
        WhaleyResources.configure()
        view.presentScene(WhaleyCreateSrcLevelTwoScene())
        view.designerProjection = designerProjection
        return view
    }

    func updateUIView(_ uiView: SrcWhaleySKView, context: Context) {
        uiView.designerProjection = designerProjection
    }
}

final class SrcWhaleySKView: SKView {
    var designerProjection: ((CGPoint, SrcWhaleySKView) -> Void)?
    let gameClock = AdjustableClockLabel()
    var clockLongPress: UILongPressGestureRecognizer!
    var clockScrub: SceneTimeScrubSession?
    var clockOriginX: CGFloat = 0
    var displayLink: CADisplayLink?
    let sceneScrubStatus = UILabel()
    let sceneScrubCallout = WhaleyScrubCalloutView()
    var objectScrubTouch: CGPoint = .zero
    var objectLongPress: UILongPressGestureRecognizer!
    var objectScrub: SceneObjectScrubSession?
    var objectScrubOrigin: CGPoint = .zero
    var lastCLIRelayPublish: CFTimeInterval = 0
    var lastCLIRelayAttempt: CFTimeInterval = 0
    var cliRelayAvailable: Bool?
    var cliRelayHelloSent = false

    var cliRelayStateURL: URL? {
        URL(string: ProcessInfo.processInfo.environment["WHALEY_RELAY_URL"] ?? "http://127.0.0.1:8092/state")
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        installSemanticClock()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        installSemanticClock()
    }

    func installSemanticClock() {

        gameClock.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
        gameClock.textColor = .white
        gameClock.backgroundColor = UIColor.black.withAlphaComponent(0.65)
        gameClock.layer.cornerRadius = 6
        gameClock.layer.masksToBounds = true
        gameClock.textAlignment = .center
        gameClock.numberOfLines = 4
        gameClock.text = "00:00.00"
        gameClock.isAccessibilityElement = false
        gameClock.isUserInteractionEnabled = true
        addSubview(gameClock)

        clockLongPress = UILongPressGestureRecognizer(target: self, action: #selector(scrubClock(_:)))
        clockLongPress.minimumPressDuration = 0.35
        clockLongPress.cancelsTouchesInView = true
        clockLongPress.allowableMovement = 10_000
        gameClock.addGestureRecognizer(clockLongPress)

        installObjectSceneScrub()
        startDisplayLink()
    }

    func installObjectSceneScrub() {
        sceneScrubStatus.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        sceneScrubStatus.textColor = .white
        sceneScrubStatus.backgroundColor = UIColor.black.withAlphaComponent(0.72)
        sceneScrubStatus.layer.cornerRadius = 6
        sceneScrubStatus.layer.masksToBounds = true
        sceneScrubStatus.textAlignment = .center
        sceneScrubStatus.isHidden = true
        sceneScrubStatus.isUserInteractionEnabled = false
        addSubview(sceneScrubStatus)

        sceneScrubCallout.isHidden = true
        sceneScrubCallout.isUserInteractionEnabled = false
        addSubview(sceneScrubCallout)

        let press = UILongPressGestureRecognizer(target: self, action: #selector(scrubObject(_:)))
        press.minimumPressDuration = 0.35
        press.allowableMovement = 10_000
        press.cancelsTouchesInView = true
        press.delaysTouchesBegan = true
        press.delegate = self
        addGestureRecognizer(press)
        objectLongPress = press
    }

    @objc func scrubObject(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            guard WhaleySrcSceneScrubBegin(location) else {
                showTransientScrubCallout(text: "No object here to scrub", anchor: location, touch: location)
                return
            }
            objectScrubOrigin = location
            objectScrubTouch = location
            objectScrub = SceneObjectScrubSession()
            showObjectScrubCallout(touch: location)
        case .changed:
            guard var scrub = objectScrub else { return }
            scrub.update(
                horizontal: Double(location.x - objectScrubOrigin.x),
                vertical: Double(location.y - objectScrubOrigin.y)
            )
            objectScrub = scrub
            objectScrubTouch = location
            WhaleySrcSceneScrubApply(scrub.category.rawValue, scrub.scalarSteps)
            showObjectScrubCallout(touch: location)
        case .ended, .cancelled, .failed:
            let acquired = objectScrub != nil
            objectScrub = nil
            sceneScrubCallout.isHidden = true
            sceneScrubStatus.isHidden = true
            if acquired { WhaleySrcSceneScrubEnd() }
        default:
            break
        }
    }

    func showObjectScrubCallout(touch: CGPoint) {
        guard let scrub = objectScrub else { return }
        let activeFrame = WhaleySrcSceneScrubActiveObjectFrame()
        let anchor =
            activeFrame.isNull || activeFrame.isEmpty
            ? objectScrubOrigin
            : CGPoint(x: activeFrame.midX, y: activeFrame.midY)
        showTransientScrubCallout(
            text: "\(scrub.category.title)   \(scrub.scalarSteps >= 0 ? "+" : "")\(scrub.scalarSteps)",
            anchor: anchor,
            touch: touch
        )
    }

    func showTransientScrubCallout(text: String, anchor: CGPoint, touch: CGPoint) {
        sceneScrubCallout.text = text
        sceneScrubCallout.update(anchor: anchor, touch: touch, in: bounds.inset(by: safeAreaInsets))
        sceneScrubCallout.isHidden = false
        bringSubviewToFront(sceneScrubCallout)
    }

    func showObjectScrubStatus() {
        guard let scrub = objectScrub else { return }
        sceneScrubStatus.text = "  \(scrub.category.title)   \(scrub.scalarSteps >= 0 ? "+" : "")\(scrub.scalarSteps)  "
        sceneScrubStatus.sizeToFit()
        sceneScrubStatus.frame.size.height = 30
        sceneScrubStatus.center = CGPoint(x: bounds.midX, y: safeAreaInsets.top + 58)
        sceneScrubStatus.isHidden = false
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            startDisplayLink()
            sendCLIRelayHelloIfNeeded()
        } else {
            displayLink?.invalidate()
            displayLink = nil
        }
    }

    func startDisplayLink() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(updateSemanticClock))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        WhaleySrcSetCompatViewSize(bounds.size)
        let clockWidth: CGFloat = clockScrub == nil ? 84 : 190
        let clockHeight: CGFloat = clockScrub == nil ? 30 : 76
        gameClock.frame = CGRect(
            x: bounds.width - clockWidth - 10,
            y: safeAreaInsets.top + 8,
            width: clockWidth,
            height: clockHeight
        )
        if objectScrub != nil, !sceneScrubCallout.isHidden { showObjectScrubCallout(touch: objectScrubTouch) }
        if !sceneScrubStatus.isHidden { showObjectScrubStatus() }
    }

    func sendCLIRelayHelloIfNeeded() {
        guard !cliRelayHelloSent, let stateURL = cliRelayStateURL else { return }
        cliRelayHelloSent = true
        let helloURL = stateURL.deletingLastPathComponent().appendingPathComponent("hello")
        print("Whaley relay endpoint: \(stateURL.absoluteString)")
        var request = URLRequest(url: helloURL)
        request.setValue("mobile", forHTTPHeaderField: "X-Whaley-Client")
        request.setValue("ios-\(ProcessInfo.processInfo.processIdentifier)", forHTTPHeaderField: "X-Whaley-Client-ID")
        URLSession.shared
            .dataTask(with: request) { [weak self] _, response, error in
                let reachable =
                    error == nil && (response as? HTTPURLResponse).map { 200..<300 ~= $0.statusCode } == true
                let errorDescription = error?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.recordCLIRelayResult(url: helloURL, reachable: reachable, errorDescription: errorDescription)
                }
            }
            .resume()
    }

    @MainActor
    func recordCLIRelayResult(url: URL, reachable: Bool, errorDescription: String?) {
        guard cliRelayAvailable != reachable else { return }
        cliRelayAvailable = reachable
        if reachable {
            print("Whaley relay connected: \(url.absoluteString)")
        } else {
            let detail = errorDescription.map { " — \($0)" } ?? ""
            print("Whaley relay unavailable: \(url.absoluteString)\(detail)")
        }
    }

    func publishCLIPositionIfNeeded() {
        let now = CACurrentMediaTime()
        let interval: CFTimeInterval = cliRelayAvailable == false ? 2.0 : 0.1
        guard now - lastCLIRelayAttempt >= interval else { return }
        lastCLIRelayAttempt = now
        sendCLIRelayHelloIfNeeded()
        let position = WhaleySrcPlayerPosition()
        guard position != .zero, let url = cliRelayStateURL else { return }
        lastCLIRelayPublish = now
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("mobile", forHTTPHeaderField: "X-Whaley-Client")
        request.setValue("ios-\(ProcessInfo.processInfo.processIdentifier)", forHTTPHeaderField: "X-Whaley-Client-ID")
        let scene = WhaleySrcSceneSnapshotElements()
        let tileWidth = (scene["tileWidth"] as? NSNumber)?.doubleValue ?? 32
        let tileHeight = (scene["tileHeight"] as? NSNumber)?.doubleValue ?? 32
        let rawElements = scene["elements"] as? [[String: Any]] ?? []
        let elements: [WhaleySceneSnapshot.Element] = rawElements.compactMap { item in
            guard let name = item["kind"] as? String,
                let kind = WhaleySceneSnapshot.Kind(rawValue: name),
                let x = (item["x"] as? NSNumber)?.intValue,
                let y = (item["y"] as? NSNumber)?.intValue
            else { return nil }
            return .init(kind: kind, x: x, y: y)
        }
        let snapshot = WhaleySceneSnapshot(
            sequence: 0,
            session: "",
            level: WhaleySrcCurrentLevelNumber(),
            gameTime: WhaleySrcGameTime(),
            dead: WhaleySrcAdventurePlayerIsDead(),
            player: .init(
                x: Int(floor(position.x / tileWidth)),
                y: Int(floor(position.y / tileHeight))
            ),
            elements: elements
        )
        request.httpBody = try? JSONEncoder().encode(snapshot)
        URLSession.shared
            .dataTask(with: request) { [weak self] _, response, error in
                let reachable =
                    error == nil && (response as? HTTPURLResponse).map { 200..<300 ~= $0.statusCode } == true
                let errorDescription = error?.localizedDescription
                Task { @MainActor [weak self] in
                    self?.recordCLIRelayResult(url: url, reachable: reachable, errorDescription: errorDescription)
                }
            }
            .resume()
    }

    @objc func updateSemanticClock() {
        designerProjection?(.zero, self)
        let adventureTime = WhaleySrcGameTime()
        publishCLIPositionIfNeeded()
        guard clockScrub == nil else { return }
        let live = SceneGameTime.seconds(WhaleySrcGameTime())
        gameClock.text = live.clockText
        gameClock.accessibilityValue = live.clockText
    }

    func updateTemporalDiagnostics(_ preview: SceneGameTime, projected: Bool) {
        let count = WhaleySrcPlayerHistorySampleCount()
        guard count > 0 else {
            gameClock.text = "\(preview.clockText)\nWhaley: no history\nprojection: unavailable"
            return
        }
        let first = SceneGameTime.seconds(WhaleySrcPlayerHistoryFirstTime()).clockText
        let last = SceneGameTime.seconds(WhaleySrcPlayerHistoryLastTime()).clockText
        gameClock.text =
            "\(preview.clockText)\nWhaley: \(count) samples\n\(first) … \(last)\n\(projected ? "projected" : "projection failed")"
    }

    @objc func scrubClock(_ recognizer: UILongPressGestureRecognizer) {
        let location = recognizer.location(in: self)
        switch recognizer.state {
        case .began:
            let live = SceneGameTime.seconds(WhaleySrcGameTime())
            clockScrub = SceneTimeScrubSession(liveTime: live)
            clockOriginX = location.x
            gameClock.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
            gameClock.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.8)
            WhaleySrcBeginTimeProjection()
            WhaleySrcSetSceneScrubPaused(true)
            updateTemporalDiagnostics(live, projected: WhaleySrcProjectTime(live.seconds))
            setNeedsLayout()
        case .changed:
            guard var scrub = clockScrub else { return }
            scrub.update(horizontal: Double(location.x - clockOriginX))
            clockScrub = scrub
            let projected = WhaleySrcProjectTime(scrub.previewTime.seconds)
            updateTemporalDiagnostics(scrub.previewTime, projected: projected)
        case .ended, .cancelled, .failed:
            WhaleySrcRestoreLiveProjection()
            clockScrub = nil
            gameClock.font = .monospacedDigitSystemFont(ofSize: 13, weight: .bold)
            gameClock.backgroundColor = UIColor.black.withAlphaComponent(0.65)
            WhaleySrcSetSceneScrubPaused(false)
            setNeedsLayout()
            updateSemanticClock()
        default:
            break
        }
    }
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            _ = WhaleySrcTouchBegan(touch, event)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            WhaleySrcTouchMoved(touch, event)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            WhaleySrcTouchEnded(touch, event)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            WhaleySrcTouchCancelled(touch, event)
        }
    }
}

extension SrcWhaleySKView: UIGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard gestureRecognizer === objectLongPress else { return true }
        if touch.view === gameClock { return false }
        if WhaleySrcHitBubble(touch.location(in: self)) { return false }
        return true
    }
}

final class WhaleyScrubCalloutView: UIView {
    enum Direction { case up, right, left, down }
    let label = UILabel()
    let bubbleLayer = CAShapeLayer()
    let tailLayer = CAShapeLayer()
    let bubbleSize = CGSize(width: 196, height: 44)
    let tileSize: CGFloat = 32
    var gap: CGFloat { tileSize * 1.5 }
    let fingerRadius: CGFloat = 52
    let edgeInset: CGFloat = 8

    var text: String {
        get { label.text ?? "" }
        set { label.text = newValue }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.addSublayer(tailLayer)
        layer.addSublayer(bubbleLayer)
        label.font = .monospacedSystemFont(ofSize: 13, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        addSubview(label)
        bubbleLayer.fillColor = UIColor.black.withAlphaComponent(0.78).cgColor
        tailLayer.fillColor = UIColor.black.withAlphaComponent(0.78).cgColor
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowRadius = 5
        layer.shadowOffset = CGSize(width: 0, height: 2)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(anchor: CGPoint, touch: CGPoint, in viewport: CGRect) {
        let placement = bestPlacement(anchor: anchor, touch: touch, viewport: viewport)
        frame = placement.frame.insetBy(dx: -10, dy: -10)
        let bubbleFrame = placement.frame.offsetBy(dx: -frame.minX, dy: -frame.minY)
        bubbleLayer.path = UIBezierPath(roundedRect: bubbleFrame, cornerRadius: 12).cgPath
        label.frame = bubbleFrame.insetBy(dx: 10, dy: 4)
        tailLayer.path =
            tailPath(
                direction: placement.direction,
                bubbleFrame: bubbleFrame,
                anchor: CGPoint(x: anchor.x - frame.minX, y: anchor.y - frame.minY)
            )
            .cgPath
    }

    struct Placement {
        let direction: Direction
        let frame: CGRect
        let score: CGFloat
    }

    func bestPlacement(anchor: CGPoint, touch: CGPoint, viewport: CGRect) -> Placement {
        let halfW = bubbleSize.width / 2
        let halfH = bubbleSize.height / 2
        let proposals: [(Direction, CGPoint)] = [
            (.up, CGPoint(x: anchor.x, y: anchor.y - halfH - gap)),
            (.right, CGPoint(x: anchor.x + halfW + gap, y: anchor.y)),
            (.left, CGPoint(x: anchor.x - halfW - gap, y: anchor.y)),
            (.down, CGPoint(x: anchor.x, y: anchor.y + halfH + gap)),
        ]
        let finger = CGRect(
            x: touch.x - fingerRadius,
            y: touch.y - fingerRadius,
            width: fingerRadius * 2,
            height: fingerRadius * 2
        )
        return proposals.enumerated()
            .map { ordinal, proposal in
                let (direction, center) = proposal
                var rect = CGRect(
                    x: center.x - halfW,
                    y: center.y - halfH,
                    width: bubbleSize.width,
                    height: bubbleSize.height
                )
                let allowed = viewport.insetBy(dx: edgeInset, dy: edgeInset)
                let dx =
                    rect.minX < allowed.minX
                    ? allowed.minX - rect.minX : (rect.maxX > allowed.maxX ? allowed.maxX - rect.maxX : 0)
                let dy =
                    rect.minY < allowed.minY
                    ? allowed.minY - rect.minY : (rect.maxY > allowed.maxY ? allowed.maxY - rect.maxY : 0)
                rect = rect.offsetBy(dx: dx, dy: dy)
                let overlap = rect.intersection(finger)
                let occlusion = overlap.isNull ? 0 : overlap.width * overlap.height * 30
                return Placement(
                    direction: direction,
                    frame: rect,
                    score: occlusion + hypot(dx, dy) * 10 + CGFloat(ordinal) * 8
                )
            }
            .min { $0.score < $1.score }!
    }

    func tailPath(direction: Direction, bubbleFrame: CGRect, anchor: CGPoint) -> UIBezierPath {
        let path = UIBezierPath()
        switch direction {
        case .up:
            let x = min(max(anchor.x, bubbleFrame.minX + 18), bubbleFrame.maxX - 18)
            path.move(to: CGPoint(x: x - 9, y: bubbleFrame.maxY - 1))
            path.addLine(to: CGPoint(x: x + 9, y: bubbleFrame.maxY - 1))
            path.addLine(to: anchor)
        case .down:
            let x = min(max(anchor.x, bubbleFrame.minX + 18), bubbleFrame.maxX - 18)
            path.move(to: CGPoint(x: x - 9, y: bubbleFrame.minY + 1))
            path.addLine(to: CGPoint(x: x + 9, y: bubbleFrame.minY + 1))
            path.addLine(to: anchor)
        case .left:
            let y = min(max(anchor.y, bubbleFrame.minY + 12), bubbleFrame.maxY - 12)
            path.move(to: CGPoint(x: bubbleFrame.maxX - 1, y: y - 8))
            path.addLine(to: CGPoint(x: bubbleFrame.maxX - 1, y: y + 8))
            path.addLine(to: anchor)
        case .right:
            let y = min(max(anchor.y, bubbleFrame.minY + 12), bubbleFrame.maxY - 12)
            path.move(to: CGPoint(x: bubbleFrame.minX + 1, y: y - 8))
            path.addLine(to: CGPoint(x: bubbleFrame.minX + 1, y: y + 8))
            path.addLine(to: anchor)
        }
        path.close()
        return path
    }
}

final class AdjustableClockLabel: UILabel {}
