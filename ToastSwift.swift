//
//  ToastSwift.swift
//
//  Created by Anatoly Esaulov on 24.08.2018.
//  Copyright © 2018 ObanzeDev. All rights reserved.
//
// Thread safe Toast info view
import UIKit

class ToastViewSwift: UIViewCommon {

    var text: String = "" {
        didSet {
            titleLabel.text = text
            invalidateIntrinsicContentSize()
        }
    }
    override var intrinsicContentSize: CGSize {
        return CGSize(width: UIViewNoIntrinsicMetric, height: titleLabel.intrinsicContentSize.height - 16)
    }
    var titleLabel: UILabel!
    
    private var shadowApplied: Bool = false
    override func commonInit() {
        backgroundColor = UIColor.black.withAlphaComponent(0.6)
        
        titleLabel = UILabel()
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.textColor = .white
        titleLabel.font = UIFont.systemFont(ofSize: 13)
        titleLabel.numberOfLines = 0
        titleLabel.backgroundColor = .clear
        titleLabel.text = text
        titleLabel.textAlignment = .center
        
        addSubview(titleLabel)
        titleLabel.addFourAnchorsToSuperview(margins: UIEdgeInsets(top: -8, left: -8, bottom: 8, right: 8))
        
        if #available(iOS 11.0, *) {
            if let appDel = UIApplication.shared.delegate,
                let mainW = appDel.window!, mainW.safeAreaInsets.bottom > 0 {
                layer.cornerRadius = 10
            }
        }
    }
    
    override class var requiresConstraintBasedLayout: Bool {
        return true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        guard !shadowApplied else {return}
        
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 5)
        layer.shadowRadius = 5
        shadowApplied = true
    }
}

class ToastSwift {
    static let shared = ToastSwift()
    private let toastMessagesPoolAccessQuerie = DispatchQueue(label: "com.obanzeDev.synchoronizedToastMessagesPoolAccessQuerie", attributes: .concurrent)
    private var iPhoneX : Bool
    private var messagesPool: [String] = []
    private var animating: Bool = false
    
    private init() {
        if #available(iOS 11.0, *) {
            if let appDel = UIApplication.shared.delegate,
            let mainW = appDel.window!, mainW.safeAreaInsets.bottom > 0 {iPhoneX = true} else {iPhoneX = false}
        } else {iPhoneX = false}
        
    }
    
    private func appendMessage(message: String) {
        self.toastMessagesPoolAccessQuerie.async(flags: .barrier) {self.messagesPool.append(message)}
    }
    
    private func getMessageFromPool() -> String? {
        var message : String?
        toastMessagesPoolAccessQuerie.sync {
            message = messagesPool.first
        }
        return message
    }
    
    private func removeShowedMessageFromPool() {
        self.toastMessagesPoolAccessQuerie.async(flags: .barrier) {
            guard !self.messagesPool.isEmpty else {return}
            self.messagesPool.removeFirst()
        }
    }
    
    private func messagesPoolIsEmpty() -> Bool {
        var isEmpty: Bool = false
        toastMessagesPoolAccessQuerie.sync {isEmpty = messagesPool.isEmpty}
        return isEmpty
    }
    
    private func show() {
        guard !animating, !messagesPoolIsEmpty() else {return}
        
        animating = true
        let windowHeight = UIScreen.main.bounds.height
        
        DispatchQueue.main.async {
            // If still has prev instanse, remove it
            for v in AppDelegate.shared().window.subviews {
                if v.tag == 999333 {v.removeFromSuperview(); break}
            }
            
            let toastView = ToastViewSwift()
            toastView.translatesAutoresizingMaskIntoConstraints = false
            toastView.tag = 999333
            toastView.text = self.getMessageFromPool() ?? ""
            toastView.alpha = 0
            AppDelegate.shared().window.addSubview(toastView)
            
            if self.iPhoneX {
                toastView.addAnchorToSuperview(anchor: .trailing, margin: 16).addAnchorToSuperview(anchor: .leading, margin: -16)
            } else {
                toastView.addAnchorToSuperview(anchor: .trailing, margin: 0).addAnchorToSuperview(anchor: .leading, margin: 0)
            }
            
            let topConstraint = toastView.topAnchor.constraint(equalTo: toastView.superview!.bottomAnchor, constant: windowHeight)
            topConstraint.isActive = true
            toastView.superview!.setNeedsLayout()
            toastView.superview!.layoutIfNeeded()
            
            if self.iPhoneX { topConstraint.constant = -(toastView.bounds.height + 32) } else {topConstraint.constant = -(toastView.bounds.height)}
            
            UIView.animate(withDuration: 0.5, animations: {
                toastView.alpha = 0.95
                toastView.superview!.setNeedsLayout()
                toastView.superview!.layoutIfNeeded()
            }) { (completed) in
                DispatchQueue.main.asyncAfter(deadline: .now() + .seconds(2)) {
                    topConstraint.constant = 0
                    UIView.animate(withDuration: 0.5, animations: {
                        toastView.alpha = 0
                        toastView.superview!.setNeedsLayout()
                        toastView.superview!.layoutIfNeeded()
                    }, completion: { (completed) in
                        toastView.removeFromSuperview()
                        self.removeShowedMessageFromPool()
                        self.animating = false
                        if !self.messagesPoolIsEmpty() {self.show()}
                    })
                }
            }
        }
    }
    static func showMessage(_ text: String) {
        ToastSwift.shared.appendMessage(message: text)
        ToastSwift.shared.show()
    }
    static func showServiceNotAvailable() {
        ToastSwift.shared.appendMessage(message: "Сервис временно недоступен.\nПроверьте подключение к интернету")
        ToastSwift.shared.show()
    }
    static func showNoInternet() {
        ToastSwift.shared.appendMessage(message: "Нет подключения к Интернету")
        ToastSwift.shared.show()
    }
}
