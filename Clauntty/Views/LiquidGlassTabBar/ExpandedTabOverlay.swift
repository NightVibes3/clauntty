import UIKit

/// Expanded overlay shown when tapping the active tab
/// Shows terminal/globe icon, title, and action buttons (close, delete, tabs)
class ExpandedTabOverlay: UIView {

    // MARK: - Callbacks

    var onClose: (() -> Void)?
    var onDelete: (() -> Void)?
    var onTabs: (() -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - Constants

    private let cornerRadius: CGFloat = 22
    private let iconSize: CGFloat = 20
    private let buttonSize: CGFloat = 32
    private let horizontalPadding: CGFloat = 16
    private let verticalPadding: CGFloat = 12
    private let rowSpacing: CGFloat = 8

    // MARK: - Views

    /// Glass effect background
    private let containerEffectView: UIVisualEffectView = {
        let effect: UIVisualEffect
        if #available(iOS 26.0, *) {
            let glassEffect = UIGlassEffect()
            glassEffect.isInteractive = true
            effect = glassEffect
        } else {
            effect = UIBlurEffect(style: .systemMaterial)
        }
        let view = UIVisualEffectView(effect: effect)
        view.clipsToBounds = true
        return view
    }()

    // Top row views
    private let typeIconView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .secondaryLabel
        return imageView
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.textAlignment = .center
        label.lineBreakMode = .byTruncatingTail
        return label
    }()

    private let closeButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        button.setImage(UIImage(systemName: "xmark", withConfiguration: config), for: .normal)
        button.tintColor = .secondaryLabel
        return button
    }()

    // Bottom row views
    private let deleteButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "trash", withConfiguration: config), for: .normal)
        button.tintColor = .systemRed
        return button
    }()

    private let tabsButton: UIButton = {
        let button = UIButton(type: .system)
        let config = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
        button.setImage(UIImage(systemName: "square.on.square", withConfiguration: config), for: .normal)
        button.tintColor = .label
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }

    private func setupView() {
        backgroundColor = .clear

        // Setup container
        containerEffectView.layer.cornerRadius = cornerRadius
        containerEffectView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(containerEffectView)

        // Setup top row
        typeIconView.translatesAutoresizingMaskIntoConstraints = false
        containerEffectView.contentView.addSubview(typeIconView)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        containerEffectView.contentView.addSubview(titleLabel)

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(handleClose), for: .touchUpInside)
        containerEffectView.contentView.addSubview(closeButton)

        // Setup bottom row
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(handleDelete), for: .touchUpInside)
        containerEffectView.contentView.addSubview(deleteButton)

        tabsButton.translatesAutoresizingMaskIntoConstraints = false
        tabsButton.addTarget(self, action: #selector(handleTabs), for: .touchUpInside)
        containerEffectView.contentView.addSubview(tabsButton)

        setupConstraints()
        setupDismissGesture()
    }

    private func setupConstraints() {
        let topRowY = verticalPadding
        let bottomRowY = verticalPadding + buttonSize + rowSpacing

        NSLayoutConstraint.activate([
            // Container fills view
            containerEffectView.topAnchor.constraint(equalTo: topAnchor),
            containerEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
            containerEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            containerEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),

            // Top row - type icon (left)
            typeIconView.leadingAnchor.constraint(equalTo: containerEffectView.contentView.leadingAnchor, constant: horizontalPadding),
            typeIconView.topAnchor.constraint(equalTo: containerEffectView.contentView.topAnchor, constant: topRowY),
            typeIconView.widthAnchor.constraint(equalToConstant: iconSize),
            typeIconView.heightAnchor.constraint(equalToConstant: iconSize),

            // Top row - close button (right)
            closeButton.trailingAnchor.constraint(equalTo: containerEffectView.contentView.trailingAnchor, constant: -horizontalPadding),
            closeButton.centerYAnchor.constraint(equalTo: typeIconView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: buttonSize),
            closeButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Top row - title (center)
            titleLabel.leadingAnchor.constraint(equalTo: typeIconView.trailingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -8),
            titleLabel.centerYAnchor.constraint(equalTo: typeIconView.centerYAnchor),

            // Bottom row - delete button (left)
            deleteButton.leadingAnchor.constraint(equalTo: containerEffectView.contentView.leadingAnchor, constant: horizontalPadding),
            deleteButton.topAnchor.constraint(equalTo: containerEffectView.contentView.topAnchor, constant: bottomRowY),
            deleteButton.widthAnchor.constraint(equalToConstant: buttonSize),
            deleteButton.heightAnchor.constraint(equalToConstant: buttonSize),

            // Bottom row - tabs button (right)
            tabsButton.trailingAnchor.constraint(equalTo: containerEffectView.contentView.trailingAnchor, constant: -horizontalPadding),
            tabsButton.centerYAnchor.constraint(equalTo: deleteButton.centerYAnchor),
            tabsButton.widthAnchor.constraint(equalToConstant: buttonSize),
            tabsButton.heightAnchor.constraint(equalToConstant: buttonSize),
        ])
    }

    private func setupDismissGesture() {
        // Tap outside to dismiss - we'll add an invisible button for the background
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleBackgroundTap))
        tap.cancelsTouchesInView = false
        containerEffectView.addGestureRecognizer(tap)
    }

    @objc private func handleBackgroundTap(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: containerEffectView.contentView)

        // Check if tap was on a button
        let buttons = [closeButton, deleteButton, tabsButton]
        for button in buttons {
            if button.frame.contains(location) {
                return // Let the button handle it
            }
        }

        // Tap was on background - dismiss
        onDismiss?()
    }

    @objc private func handleClose() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        onClose?()
    }

    @objc private func handleDelete() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        onDelete?()
    }

    @objc private func handleTabs() {
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()
        onTabs?()
    }

    // MARK: - Configuration

    func configure(tab: TabItem) {
        titleLabel.text = tab.title

        let config = UIImage.SymbolConfiguration(pointSize: iconSize, weight: .medium)

        switch tab {
        case .terminal:
            typeIconView.image = UIImage(systemName: "terminal", withConfiguration: config)
            typeIconView.tintColor = .secondaryLabel
        case .web:
            typeIconView.image = UIImage(systemName: "globe", withConfiguration: config)
            typeIconView.tintColor = .systemBlue
        }
    }
}
