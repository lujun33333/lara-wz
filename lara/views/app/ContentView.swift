import Combine
import UIKit

enum AXLauncherAuthorizationState: Equatable {
    case unverified
    case verifying
    case activated(expiryText: String)
    case expired(expiryText: String?)
    case failed(message: String)
    #if AX_LOCAL_TEST_AUTH_BYPASS
    case localTesting
    #endif

    static var initialForCurrentBuild: Self {
        applyingBuildPolicy(to: .unverified)
    }

    static func applyingBuildPolicy(to state: Self) -> Self {
        #if AX_LOCAL_TEST_AUTH_BYPASS
        precondition(ax_launcher_local_test_authorization_bypass_enabled())
        return .localTesting
        #else
        return state
        #endif
    }

    var showsActivationForm: Bool {
        switch self {
        case .activated:
            return false
        #if AX_LOCAL_TEST_AUTH_BYPASS
        case .localTesting:
            return false
        #endif
        default:
            return true
        }
    }

    var canLaunch: Bool {
        switch self {
        case .activated:
            return true
        #if AX_LOCAL_TEST_AUTH_BYPASS
        case .localTesting:
            return true
        #endif
        default:
            return false
        }
    }

    var isActivated: Bool { canLaunch }

    func statusText(managerStatus: String) -> String {
        switch self {
        case .unverified:
            return managerStatus
        case .verifying:
            return "正在验证卡密…"
        case let .activated(expiryText):
            return "到期时间：\(expiryText)"
        case let .expired(expiryText):
            guard let expiryText, !expiryText.isEmpty else { return "授权已过期" }
            return "授权已过期：\(expiryText)"
        case let .failed(message):
            return message
        #if AX_LOCAL_TEST_AUTH_BYPASS
        case .localTesting:
            return "LOCAL TEST AUTH BYPASS · 已跳过卡密验证"
        #endif
        }
    }
}

@objc(AXGradientButton)
final class AXLauncherGradientButton: UIButton {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
}

@objc(AXGradientTintView)
final class AXLauncherGradientTintView: UIView {
    override class var layerClass: AnyClass { CAGradientLayer.self }

    var gradientLayer: CAGradientLayer {
        layer as! CAGradientLayer
    }
}

@objc(BYG6trFgTr5X)
final class AXLauncherViewController: UIViewController {
    // AX 1.2.8: BYG6trFgTr5X viewDidLoad @ 0x10004ed48 and
    // jZtCjHXgjK @ 0x10004f964.
    private let baseGradientLayer = CAGradientLayer()
    private let auroraTopLayer = CAGradientLayer()
    private let auroraBottomLayer = CAGradientLayer()
    private let starLayer = CALayer()

    private let cardView = UIView()
    private let cardHighlightView = AXLauncherGradientTintView()
    private let separatorView = AXGradientRuleView()

    private let titleLabel = UILabel()
    private let versionLabel = UILabel()
    private let supportCard = UIView()
    private let supportTitleLabel = UILabel()
    private let supportStatusLabel = UILabel()
    private let activationField = UITextField()
    private let activationButton = AXLauncherGradientButton(type: .system)
    private let statusCard = UIView()
    private let statusTitleLabel = UILabel()
    private let statusLabel = UILabel()
    private let expiryLabel = UILabel()
    private let spacerView = UIView()
    private let launchButton = AXLauncherGradientButton(type: .system)
    private let progressContainer = UIView()
    private let progressLabel = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private let stackView = UIStackView()

    private var mgr: laramgr
    private var authorizationState: AXLauncherAuthorizationState
    private var managerObservation: AnyCancellable?
    private var lastSBXReady = false
    private var didBootstrapEnvironment = false
    private var starsBuilt = false

    init(manager: laramgr, authorizationState: AXLauncherAuthorizationState) {
        self.mgr = manager
        self.authorizationState = .applyingBuildPolicy(to: authorizationState)
        super.init(nibName: nil, bundle: nil)
        manager.updateWZAuthorizationAccess(self.authorizationState.canLaunch)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var shouldAutorotate: Bool { false }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .portrait }

    override func viewDidLoad() {
        super.viewDidLoad()
        observeManager()
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = axColor(0.016, 0.018, 0.040)

        configureBackgroundLayers()
        configureCard()
        configureMainContent()
        configureConstraints()
        updatePresentation()
        bootstrapEnvironmentIfNeeded()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // AX 1.2.8: BYG6trFgTr5X viewDidLayoutSubviews @ 0x10004f020.
        let bounds = view.bounds
        baseGradientLayer.frame = bounds
        auroraTopLayer.frame = CGRect(
            x: -0.25 * bounds.width,
            y: -0.30 * bounds.height,
            width: 1.50 * bounds.width,
            height: 0.85 * bounds.height
        )
        auroraBottomLayer.frame = CGRect(
            x: -0.35 * bounds.width,
            y: 0.62 * bounds.height,
            width: 1.70 * bounds.width,
            height: 0.75 * bounds.height
        )
        starLayer.frame = bounds

        cardHighlightView.frame = CGRect(x: 0, y: 0, width: cardView.bounds.width, height: 44)
        separatorView.updateGradientFrame()

        if !starsBuilt, bounds.width >= 1, bounds.height >= 1 {
            buildStars(in: bounds)
            starsBuilt = true
        }
    }

    func updateAuthorizationState(_ state: AXLauncherAuthorizationState) {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.updateAuthorizationState(state)
            }
            return
        }
        authorizationState = .applyingBuildPolicy(to: state)
        mgr.updateWZAuthorizationAccess(authorizationState.canLaunch)
        if isViewLoaded {
            updatePresentation()
        }
    }

    private func observeManager() {
        lastSBXReady = mgr.sbxready
        managerObservation = mgr.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                let becameReady = !self.lastSBXReady && self.mgr.sbxready
                self.lastSBXReady = self.mgr.sbxready
                self.updatePresentation()
                if becameReady {
                    IconThemeManager.shared.startPendingFixupIfPossible()
                }
            }
        }
    }

    private func bootstrapEnvironmentIfNeeded() {
        guard !didBootstrapEnvironment else { return }
        didBootstrapEnvironment = true

        let support = axDeviceSupportStatus()
        guard support.isSupported else {
            Alertinator.shared.alert(
                title: "此设备不受支持！",
                body: "\(support.marketingName) · iOS \(UIDevice.current.systemVersion)\n\(support.reason ?? "不在 AX 1.2.8 支持范围")",
                actionLabel: "退出应用",
                action: { exitinator() }
            )
            return
        }

        init_offsets()
        offsets_init()
        IconThemeManager.shared.startPendingFixupIfPossible()
        mgr.hasOffsets = emergencyfixfunctiontobereplacedlateronquestionmark()
    }

    private func configureBackgroundLayers() {
        baseGradientLayer.colors = [
            axColor(0.016, 0.018, 0.042).cgColor,
            axColor(0.058, 0.052, 0.125).cgColor,
            axColor(0.020, 0.020, 0.048).cgColor,
        ]
        baseGradientLayer.locations = [0, 0.58, 1]
        baseGradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        baseGradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        auroraTopLayer.colors = [
            axColor(0.46, 0.34, 0.98, 0.20).cgColor,
            axColor(0.30, 0.24, 0.78, 0.06).cgColor,
            UIColor.clear.cgColor,
        ]
        auroraTopLayer.locations = [0, 0.55, 1]
        auroraTopLayer.startPoint = CGPoint(x: 0.15, y: 0)
        auroraTopLayer.endPoint = CGPoint(x: 0.85, y: 1)
        auroraTopLayer.compositingFilter = "screen"

        auroraBottomLayer.colors = [
            UIColor.clear.cgColor,
            axColor(0.22, 0.30, 0.90, 0.08).cgColor,
            axColor(0.40, 0.30, 0.95, 0.16).cgColor,
        ]
        auroraBottomLayer.locations = [0, 0.55, 1]
        auroraBottomLayer.startPoint = CGPoint(x: 0.10, y: 0)
        auroraBottomLayer.endPoint = CGPoint(x: 0.90, y: 1)
        auroraBottomLayer.compositingFilter = "screen"

        view.layer.insertSublayer(baseGradientLayer, at: 0)
        view.layer.insertSublayer(auroraTopLayer, above: baseGradientLayer)
        view.layer.insertSublayer(auroraBottomLayer, above: auroraTopLayer)
        view.layer.insertSublayer(starLayer, above: auroraBottomLayer)
    }

    private func configureCard() {
        cardView.translatesAutoresizingMaskIntoConstraints = false
        cardView.backgroundColor = axColor(0.055, 0.058, 0.115, 0.88)
        cardView.layer.cornerRadius = 22
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = axColor(0.62, 0.58, 1.00, 0.22).cgColor
        cardView.layer.shadowColor = axColor(0.02, 0.02, 0.06).cgColor
        cardView.layer.shadowOffset = CGSize(width: 0, height: 20)
        cardView.layer.shadowRadius = 34
        cardView.layer.shadowOpacity = 0.42

        cardHighlightView.isUserInteractionEnabled = false
        cardHighlightView.autoresizingMask = [.flexibleWidth, .flexibleBottomMargin]
        cardHighlightView.layer.cornerRadius = 22
        cardHighlightView.layer.masksToBounds = true
        cardHighlightView.gradientLayer.colors = [
            axColor(1, 1, 1, 0.14).cgColor,
            UIColor.clear.cgColor,
        ]
        cardHighlightView.gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        cardHighlightView.gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)

        view.addSubview(cardView)
        cardView.addSubview(cardHighlightView)
    }

    private func configureMainContent() {
        // AX 1.2.8: Wu5ojXWpGE @ 0x100051600.
        configureLabel(
            titleLabel,
            text: "AX Pro",
            font: .systemFont(ofSize: 44, weight: .black),
            color: axColor(0.97, 0.97, 1),
            alignment: .center
        )
        titleLabel.attributedText = NSAttributedString(
            string: "AX Pro",
            attributes: [.kern: 2.5]
        )

        let versionText = String(format: "VERSION %@", "1.2.8")
        configureLabel(
            versionLabel,
            text: versionText,
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: axColor(0.60, 0.62, 0.80),
            alignment: .center
        )
        versionLabel.attributedText = NSAttributedString(
            string: versionText,
            attributes: [.kern: 1.6]
        )

        configureSupportCard()
        configureActivationField()
        configureButton(
            activationButton,
            title: "卡密激活",
            symbol: "checkmark.seal.fill",
            action: #selector(activateCard)
        )
        activationButton.tag = 0xc73a

        configureLabel(
            statusLabel,
            text: "",
            font: .systemFont(ofSize: 15, weight: .semibold),
            color: axColor(0.74, 0.76, 0.90),
            alignment: .left
        )
        statusLabel.numberOfLines = 0
        configureLabel(
            expiryLabel,
            text: "",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: axColor(0.66, 0.95, 0.82),
            alignment: .left
        )
        expiryLabel.numberOfLines = 0
        expiryLabel.tag = 0xc73b
        configureStatusCard()

        spacerView.translatesAutoresizingMaskIntoConstraints = false
        spacerView.heightAnchor.constraint(equalToConstant: 2).isActive = true

        configureButton(
            launchButton,
            title: "启动应用",
            symbol: "play.fill",
            action: #selector(launchApplication)
        )
        configureProgress()

        let arrangedSubviews: [UIView] = [
            titleLabel,
            versionLabel,
            separatorView,
            supportCard,
            activationField,
            activationButton,
            statusCard,
            spacerView,
            launchButton,
            progressContainer,
        ]
        arrangedSubviews.forEach(stackView.addArrangedSubview)
        stackView.axis = .vertical
        stackView.spacing = 12
        stackView.alignment = .fill
        stackView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(stackView)
    }

    private func configureSupportCard() {
        supportCard.translatesAutoresizingMaskIntoConstraints = false
        supportCard.backgroundColor = axColor(0.05, 0.07, 0.10)
        supportCard.layer.cornerRadius = 14
        supportCard.layer.borderWidth = 1
        supportCard.layer.borderColor = axColor(0.36, 0.70, 0.56, 0.36).cgColor

        configureLabel(
            supportTitleLabel,
            text: "设备与系统支持",
            font: .systemFont(ofSize: 12, weight: .bold),
            color: axColor(0.72, 0.78, 0.86),
            alignment: .left
        )
        configureLabel(
            supportStatusLabel,
            text: "正在检查当前环境…",
            font: .systemFont(ofSize: 13, weight: .semibold),
            color: axColor(1.00, 0.84, 0.52),
            alignment: .left
        )
        supportStatusLabel.numberOfLines = 0

        let supportStack = UIStackView(arrangedSubviews: [supportTitleLabel, supportStatusLabel])
        supportStack.axis = .vertical
        supportStack.spacing = 6
        supportStack.translatesAutoresizingMaskIntoConstraints = false
        supportCard.addSubview(supportStack)
        NSLayoutConstraint.activate([
            supportStack.topAnchor.constraint(equalTo: supportCard.topAnchor, constant: 12),
            supportStack.leadingAnchor.constraint(equalTo: supportCard.leadingAnchor, constant: 14),
            supportStack.trailingAnchor.constraint(equalTo: supportCard.trailingAnchor, constant: -14),
            supportStack.bottomAnchor.constraint(equalTo: supportCard.bottomAnchor, constant: -12),
        ])
    }

    private func configureActivationField() {
        activationField.translatesAutoresizingMaskIntoConstraints = false
        activationField.placeholder = "请输入卡密"
        activationField.textColor = axColor(0.93, 0.93, 0.99)
        activationField.tintColor = axColor(0.66, 0.58, 1)
        activationField.font = .systemFont(ofSize: 16, weight: .semibold)
        activationField.autocorrectionType = .no
        activationField.autocapitalizationType = .none
        activationField.clearButtonMode = .whileEditing
        activationField.returnKeyType = .done
        activationField.backgroundColor = axColor(0.04, 0.042, 0.088)
        activationField.layer.cornerRadius = 14
        activationField.layer.borderWidth = 1
        activationField.layer.borderColor = axColor(0.55, 0.50, 1, 0.32).cgColor
        activationField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 14, height: 1))
        activationField.leftViewMode = .always
        activationField.attributedPlaceholder = NSAttributedString(
            string: "请输入卡密",
            attributes: [.foregroundColor: axColor(0.50, 0.52, 0.70)]
        )
        activationField.tag = 0xc739
    }

    private func configureStatusCard() {
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        statusCard.backgroundColor = axColor(0.04, 0.042, 0.088)
        statusCard.layer.cornerRadius = 14
        statusCard.layer.borderWidth = 1
        statusCard.layer.borderColor = axColor(0.55, 0.50, 1, 0.28).cgColor

        configureLabel(
            statusTitleLabel,
            text: "当前状态",
            font: .systemFont(ofSize: 12, weight: .bold),
            color: axColor(0.72, 0.65, 1),
            alignment: .left
        )

        let statusStack = UIStackView(arrangedSubviews: [statusTitleLabel, statusLabel, expiryLabel])
        statusStack.axis = .vertical
        statusStack.spacing = 7
        statusStack.translatesAutoresizingMaskIntoConstraints = false
        statusCard.addSubview(statusStack)
        NSLayoutConstraint.activate([
            statusStack.topAnchor.constraint(equalTo: statusCard.topAnchor, constant: 13),
            statusStack.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 14),
            statusStack.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -14),
            statusStack.bottomAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: -13),
        ])
    }

    private func configureProgress() {
        progressContainer.translatesAutoresizingMaskIntoConstraints = false
        progressContainer.isHidden = true

        configureLabel(
            progressLabel,
            text: "0%",
            font: .monospacedDigitSystemFont(ofSize: 13, weight: .bold),
            color: axColor(0.82, 0.78, 1),
            alignment: .center
        )
        progressView.translatesAutoresizingMaskIntoConstraints = false
        progressView.progress = 0
        progressView.trackTintColor = axColor(0.10, 0.10, 0.20)
        progressView.progressTintColor = axColor(0.58, 0.50, 1)
        progressView.layer.cornerRadius = 2
        progressView.clipsToBounds = true

        progressContainer.addSubview(progressLabel)
        progressContainer.addSubview(progressView)
        NSLayoutConstraint.activate([
            progressLabel.topAnchor.constraint(equalTo: progressContainer.topAnchor),
            progressLabel.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressLabel.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressView.topAnchor.constraint(equalTo: progressLabel.bottomAnchor, constant: 8),
            progressView.leadingAnchor.constraint(equalTo: progressContainer.leadingAnchor),
            progressView.trailingAnchor.constraint(equalTo: progressContainer.trailingAnchor),
            progressView.heightAnchor.constraint(equalToConstant: 4),
            progressView.bottomAnchor.constraint(lessThanOrEqualTo: progressContainer.bottomAnchor),
        ])
    }

    private func configureConstraints() {
        let safeArea = view.safeAreaLayoutGuide
        NSLayoutConstraint.activate([
            cardView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 22),
            cardView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -22),
            cardView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -12),
            cardView.topAnchor.constraint(greaterThanOrEqualTo: safeArea.topAnchor, constant: 18),
            cardView.bottomAnchor.constraint(lessThanOrEqualTo: safeArea.bottomAnchor, constant: -18),

            stackView.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 22),
            stackView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 20),
            stackView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -20),
            stackView.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -22),

            activationField.heightAnchor.constraint(equalToConstant: 48),
            activationButton.heightAnchor.constraint(equalToConstant: 52),
            launchButton.heightAnchor.constraint(equalToConstant: 52),
            progressContainer.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    private func configureLabel(
        _ label: UILabel,
        text: String,
        font: UIFont,
        color: UIColor,
        alignment: NSTextAlignment
    ) {
        label.text = text
        label.font = font
        label.textColor = color
        label.textAlignment = alignment
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.82
        label.translatesAutoresizingMaskIntoConstraints = false
    }

    private func configureButton(
        _ button: UIButton,
        title: String,
        symbol: String,
        action: Selector
    ) {
        // AX 1.2.8 JxL6SFWVmy:symbol:style: style 0 @ 0x1000579b4.
        button.translatesAutoresizingMaskIntoConstraints = false
        button.backgroundColor = axColor(0.10, 0.105, 0.20)
        button.tintColor = axColor(0.80, 0.81, 0.94)
        button.layer.borderColor = axColor(0.42, 0.42, 0.70, 0.50).cgColor
        button.layer.shadowColor = axColor(0.02, 0.02, 0.06).cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 8)
        button.layer.shadowRadius = 14
        button.layer.shadowOpacity = 0.26
        button.layer.cornerRadius = 16
        button.layer.borderWidth = 1
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .bold)
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 18, bottom: 0, right: 18)
        button.imageEdgeInsets = UIEdgeInsets(top: 0, left: -8, bottom: 0, right: 8)
        button.titleLabel?.adjustsFontSizeToFitWidth = true
        button.titleLabel?.minimumScaleFactor = 0.82
        button.contentHorizontalAlignment = .center
        button.setTitle(title, for: .normal)
        button.setTitleColor(button.tintColor, for: .normal)
        button.setTitleColor(button.tintColor.withAlphaComponent(0.48), for: .disabled)
        button.setImage(UIImage(systemName: symbol), for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
    }

    private func updatePresentation() {
        let deviceSupport = axDeviceSupportStatus()
        let kernelReady = mgr.dsready && mgr.hasOffsets
        let accent: UIColor
        let supportText: String

        let platformText = "\(deviceSupport.marketingName) · iOS \(UIDevice.current.systemVersion)"
        if !deviceSupport.isSupported {
            accent = axColor(1.00, 0.36, 0.42)
            supportText = "✕ 当前环境不受支持\n\(platformText)\n验证与启动功能已停用"
        } else if authorizationState.isActivated || kernelReady {
            accent = axColor(0.36, 0.94, 0.62)
            supportText = "✓ 当前环境支持\n\(platformText)"
        } else {
            accent = axColor(1.00, 0.84, 0.52)
            supportText = "! 当前环境待测试\n\(platformText)\n当前系统尚未完成实机验证，请谨慎继续"
        }

        supportStatusLabel.text = supportText
        supportStatusLabel.textColor = accent
        supportCard.layer.borderColor = accent.withAlphaComponent(0.46).cgColor
        supportCard.backgroundColor = accent.withAlphaComponent(0.08)

        activationField.isHidden = !authorizationState.showsActivationForm
        activationButton.isHidden = !authorizationState.showsActivationForm
        activationButton.isEnabled = authorizationState != .verifying
        launchButton.isEnabled = authorizationState != .verifying
        statusLabel.text = authorizationState.statusText(managerStatus: mgr.wzStatus)
        statusLabel.textColor = authorizationState.isActivated
            ? axColor(0.36, 0.94, 0.62)
            : axColor(0.74, 0.76, 0.90)
        expiryLabel.text = authorizationState.isActivated && mgr.wzGameHUDEnabled
            ? mgr.wzGameHUDStatus
            : ""

        let progress = Float(min(max(mgr.dsprogress, 0), 1))
        progressContainer.isHidden = !mgr.dsrunning
        progressLabel.text = "\(Int(progress * 100))%"
        progressView.setProgress(progress, animated: false)
    }

    private func buildStars(in bounds: CGRect) {
        // AX 1.2.8: qkn9X7uTCw @ 0x10006e3bc creates 34 shape layers.
        let width = UInt32(max(1, Int(bounds.width)))
        let height = UInt32(max(1, Int(bounds.height * 0.72)))

        for index in 0..<34 {
            let size = CGFloat(arc4random_uniform(16)) / 10 + 1
            let x = CGFloat(arc4random_uniform(width))
            let y = CGFloat(arc4random_uniform(height))
            let star = CAShapeLayer()
            star.frame = CGRect(x: x, y: y, width: size, height: size)
            star.path = UIBezierPath(ovalIn: CGRect(x: 0, y: 0, width: size, height: size)).cgPath
            star.fillColor = (index % 4 == 0
                ? axColor(0.76, 0.70, 1)
                : UIColor(white: 1, alpha: 0.96)).cgColor
            star.opacity = Float(arc4random_uniform(18)) / 100 + 0.10
            starLayer.addSublayer(star)

            let twinkle = CABasicAnimation(keyPath: "opacity")
            twinkle.fromValue = Double(arc4random_uniform(8)) / 100 + 0.08
            twinkle.toValue = Double(arc4random_uniform(12)) / 100 + 0.22
            twinkle.duration = Double(arc4random_uniform(260)) / 100 + 2.4
            twinkle.autoreverses = true
            twinkle.repeatCount = .infinity
            twinkle.beginTime = CACurrentMediaTime() + Double(arc4random_uniform(200)) / 100
            star.add(twinkle, forKey: "twinkle")
        }
    }

    @objc private func activateCard() {
        let code = activationField.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !code.isEmpty else {
            presentNotice("请输入卡密。")
            return
        }

        // Authorization transport, credentials, Keychain, certificate checks,
        // and persisted state are intentionally outside this local UI replica.
        presentNotice("当前工程尚未接入 AX 卡密验证服务，无法在这里验证 AX 卡密。")
    }

    @objc private func launchApplication() {
        guard authorizationState.canLaunch else {
            presentNotice("请先完成卡密验证。当前工程尚未接入 AX 卡密验证服务。")
            return
        }
        mgr.launchWZGame()
    }

    private func presentNotice(_ message: String) {
        guard presentedViewController == nil else { return }
        let alert = UIAlertController(title: "AX Pro", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "确定", style: .cancel))
        present(alert, animated: true)
    }

}

private final class AXGradientRuleView: UIView {
    private let ruleView = AXLauncherGradientTintView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        ruleView.translatesAutoresizingMaskIntoConstraints = false
        ruleView.layer.cornerRadius = 1.5
        ruleView.layer.masksToBounds = true
        ruleView.gradientLayer.colors = [
            axColor(0.36, 0.36, 0.89).cgColor,
            axColor(0.66, 0.61, 1).cgColor,
            axColor(1, 0.44, 0.53).cgColor,
        ]
        ruleView.gradientLayer.locations = [0, 0.58, 1]
        ruleView.gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        ruleView.gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        addSubview(ruleView)
        NSLayoutConstraint.activate([
            ruleView.centerXAnchor.constraint(equalTo: centerXAnchor),
            ruleView.topAnchor.constraint(equalTo: topAnchor),
            ruleView.bottomAnchor.constraint(equalTo: bottomAnchor),
            ruleView.widthAnchor.constraint(equalToConstant: 56),
            ruleView.heightAnchor.constraint(equalToConstant: 3),
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateGradientFrame()
    }

    func updateGradientFrame() {
        ruleView.gradientLayer.setNeedsDisplay()
    }
}

private func axColor(
    _ red: CGFloat,
    _ green: CGFloat,
    _ blue: CGFloat,
    _ alpha: CGFloat = 1
) -> UIColor {
    UIColor(red: red, green: green, blue: blue, alpha: alpha)
}
