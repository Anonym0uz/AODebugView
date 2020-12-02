//
//  AODebugView.swift
//  AODebugView
//
//  Created by Alexander Orlov on 01.12.2020.
//  Copyright © 2020 Alexander Orlov. All rights reserved.
//

import UIKit

public enum LogLevel: String {
    case w = "[⚠️]"
    case e = "[‼️]"
    case i = "[ℹ️]"
    case d = "[💬]"
}

public class AODebugView: UIView {
    
    var updateTimer: Timer!
    
    private let logLabel: UILabel = {
        let lbl = UILabel()
        lbl.translatesAutoresizingMaskIntoConstraints = false
        lbl.numberOfLines = 0
        lbl.font = .systemFont(ofSize: 12, weight: .medium)
        lbl.textColor = .white
        lbl.textAlignment = .left
        lbl.text = ""
        return lbl
    }()
    
    private let rootScrollView: UIScrollView = {
        let sc = UIScrollView()
        sc.translatesAutoresizingMaskIntoConstraints = false
        sc.backgroundColor = .clear
        sc.alwaysBounceVertical = true
        return sc
    }()
    
    private let rootContentView: UIView = {
        let v = UIView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.backgroundColor = .clear
        return v
    }()
    
    private let topStackView: UIStackView = {
        let st = UIStackView()
        st.translatesAutoresizingMaskIntoConstraints = false
        st.axis = .horizontal
        st.spacing = 10
        st.alignment = .fill
        st.distribution = .fillEqually
        return st
    }()
    
    private let startRecordButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Refresh: off", for: .normal)
        b.setTitleColor(.white, for: .normal)
        return b
    }()
    
    private let clearButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Clear log", for: .normal)
        b.setTitleColor(.white, for: .normal)
        return b
    }()
    
    private let closeButton: UIButton = {
        let b = UIButton()
        b.translatesAutoresizingMaskIntoConstraints = false
        b.setTitle("Close", for: .normal)
        b.setTitleColor(.white, for: .normal)
        return b
    }()
    
    private var fileMonitor: AOFileMonitor!
    
    init() {
        super.init(frame: .zero)
    }
    
    // MARK: - Standart init
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension AODebugView {
    static func show() {
        AODebugView().createMainView()
    }
    
    public static func insertLog( _ object: Any...,
                                  level: LogLevel = .i,
                                  filename: String = #file,
                                  line: Int = #line,
                                  column: Int = #column,
                                  funcName: String = #function) {
        NSLog("\(level.rawValue)[\(sourceFileName(filePath: filename))]:\(line) \(funcName) \(object)\n")
    }
    
    public static func redirectLogs() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        let fileName = "AppLog.log"
        let logFilePath = (documentsDirectory as NSString).appendingPathComponent(fileName)
        freopen(logFilePath.cString(using: String.Encoding.ascii)!, "a+", stderr)
    }
    
    func setupText(_ url: URL) -> String {
        do {
            let text2 = try String(contentsOf: url, encoding: .utf8)
            return text2
        } catch let error {
            print(error.localizedDescription)
            return "---"
        }
    }
    
    private class func sourceFileName(filePath: String) -> String {
        let components = filePath.components(separatedBy: "/")
        return components.isEmpty ? "" : components.last!
    }
}

private extension AODebugView {
    func createMainView() {
        translatesAutoresizingMaskIntoConstraints = false
        backgroundColor = UIColor.black.withAlphaComponent(0.8)
        layer.borderWidth = 1
        layer.borderColor = UIColor.lightGray.cgColor
        clipsToBounds = true
        layer.cornerRadius = 10
        
        [startRecordButton, clearButton, closeButton].forEach({ topStackView.addArrangedSubview($0) })
        startRecordButton.addTarget(self, action: #selector(recordClicked(_:)), for: .touchUpInside)
        clearButton.addTarget(self, action: #selector(clearClicked(_:)), for: .touchUpInside)
        closeButton.addTarget(self, action: #selector(closeClicked(_:)), for: .touchUpInside)
        
        addSubview(topStackView)
        
        
        if let topVC = UIApplication.getTopViewController() {
            guard let navigation = topVC.navigationController else {
                return
            }
            alpha = 0
            
            animateView(navigation)
        }
    }
    
    func animateDismiss(_ navigation: UINavigationController, view: UIView) {
        if (view as! AODebugView).fileMonitor != nil {
            (view as! AODebugView).fileMonitor.delegate = nil
            (view as! AODebugView).fileMonitor = nil
        }

        (view as! AODebugView).fileMonitor = nil
        
        UIView.animate(withDuration: 0.3) {
            view.alpha = 0
        } completion: { _ in
            view.removeFromSuperview()
        }
        
    }
    
    func animateView(_ navigation: UINavigationController) {
        for view in navigation.view.subviews {
            if view is AODebugView {
                animateDismiss(navigation, view: view)
                return
            }
        }
        
        startRecord()
        
        navigation.view.addSubview(self)
        navigation.view.bringSubviewToFront(self)
        layer.zPosition = CGFloat(Float.greatestFiniteMagnitude)
        
        if UIDevice.isiPad {
            centerXAnchor.constraint(equalTo: navigation.view.centerXAnchor, constant: 0).isActive = true
            centerYAnchor.constraint(equalTo: navigation.view.centerYAnchor, constant: 0).isActive = true
            
            bottomAnchor.constraint(equalTo: navigation.view.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
            
            heightAnchor.constraint(equalToConstant: 230).isActive = true
            widthAnchor.constraint(equalToConstant: 150).isActive = true
        } else {
            leadingAnchor.constraint(equalTo: navigation.view.safeAreaLayoutGuide.leadingAnchor, constant: 10).isActive = true
            trailingAnchor.constraint(equalTo: navigation.view.safeAreaLayoutGuide.trailingAnchor, constant: -10).isActive = true
            
            bottomAnchor.constraint(equalTo: navigation.view.safeAreaLayoutGuide.bottomAnchor, constant: -10).isActive = true
            
            heightAnchor.constraint(equalToConstant: 230).isActive = true
        }
        
        setupViews()
        
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1
        }
    }
    
    func setupViews() {
        addSubview(rootScrollView)
        rootScrollView.addSubview(rootContentView)
        rootContentView.addSubview(logLabel)
        
        setupConstraints()
    }
    
    func setupConstraints() {
        
        topStackView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        topStackView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
        topStackView.topAnchor.constraint(equalTo: topAnchor, constant: 10).isActive = true
        topStackView.heightAnchor.constraint(equalToConstant: 25).isActive = true
        
        rootScrollView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10).isActive = true
        rootScrollView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
        rootScrollView.topAnchor.constraint(equalTo: topStackView.bottomAnchor, constant: 10).isActive = true
        rootScrollView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10).isActive = true
        
        rootContentView.leadingAnchor.constraint(equalTo: rootScrollView.leadingAnchor, constant: 0).isActive = true
        rootContentView.trailingAnchor.constraint(equalTo: rootScrollView.trailingAnchor, constant: 0).isActive = true
        rootContentView.topAnchor.constraint(equalTo: rootScrollView.topAnchor, constant: 0).isActive = true
        rootContentView.bottomAnchor.constraint(equalTo: rootScrollView.bottomAnchor, constant: 0).isActive = true
        rootContentView.widthAnchor.constraint(equalTo: rootScrollView.widthAnchor, constant: 0).isActive = true
        
        logLabel.leadingAnchor.constraint(equalTo: rootContentView.leadingAnchor, constant: 0).isActive = true
        logLabel.trailingAnchor.constraint(equalTo: rootContentView.trailingAnchor, constant: 0).isActive = true
        logLabel.topAnchor.constraint(equalTo: rootContentView.topAnchor, constant: 0).isActive = true
        logLabel.bottomAnchor.constraint(equalTo: rootContentView.bottomAnchor, constant: 0).isActive = true
    }
    
    @objc func updateText() {
        let fileName = "AppLog.log"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            logLabel.text = AODebugView().setupText(fileURL)
        }
    }
    
    func stopRecord() {
        fileMonitor.delegate = nil
        fileMonitor = nil
    }
    
    func startRecord() {
        let fileName = "AppLog.log"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            
            self.fileMonitor = try! AOFileMonitor(url: fileURL)
            self.fileMonitor.delegate = self
            
            if let labelText = logLabel.text {
                if labelText.isEmpty {
                    updateText()
                    
                    DispatchQueue.main.async {
                        let bottomOffset = CGPoint(x: 0, y: self.rootScrollView.contentSize.height - self.rootScrollView.bounds.size.height)
                        self.rootScrollView.setContentOffset(bottomOffset, animated: true)
                    }
                }
            }
            else { updateText() }
        }
    }
}

extension AODebugView: AOFileMonitorDelegate {
    func didReceive(changes: String) {
        
        UIView.transition(with: logLabel,
                          duration: 0.5,
                          options: [.curveEaseOut]) {
            if !changes.isEmpty {
                self.logLabel.text! += changes
            } else {
                self.updateText()
            }
        } completion: { (success) in
            DispatchQueue.main.async {
                let bottomOffset = CGPoint(x: 0, y: self.rootScrollView.contentSize.height - self.rootScrollView.bounds.size.height)
                self.rootScrollView.setContentOffset(bottomOffset, animated: true)
            }
        }
    }
}

private extension AODebugView {
    @objc func recordClicked(_ sender: UIButton) {
        if sender.title(for: .normal) == "Refresh: off" {
            sender.setTitle("Refresh: on", for: .normal)
            stopRecord()
        } else {
            sender.setTitle("Refresh: off", for: .normal)
            startRecord()
        }
    }
    
    @objc func clearClicked(_ sender: UIButton) {
        let fileName = "AppLog.log"
        if let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = dir.appendingPathComponent(fileName)
            let text = ""
            do {
                try text.write(to: fileURL, atomically: false, encoding: .utf8)
            } catch let error {
                print(error.localizedDescription)
            }
        }
    }
    
    @objc func closeClicked(_ sender: UIButton) {
        AODebugView.show()
    }
}


// MARK: - Extensions

public extension UINavigationBar {
    private static var debugGesture: UILongPressGestureRecognizer!
    
    func debugViewEnabled(_ enabled: Bool) {
        if let gesture = UINavigationBar.debugGesture {
            removeGestureRecognizer(gesture)
        }
        UINavigationBar.debugGesture = UILongPressGestureRecognizer(target: self, action: #selector(addGesture(_:)))
        UINavigationBar.debugGesture.minimumPressDuration = 0.4
        (enabled) ? addGestureRecognizer(UINavigationBar.debugGesture) : nil
    }
    
    @objc private func addGesture(_ sender: UILongPressGestureRecognizer) {
        if sender.state == .began {
            AODebugView.show()
        }
    }
}

private extension UIApplication {
    class func getTopViewController(base: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)

        } else if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)

        } else if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return base
    }
}

private extension UIDevice {
    static var isiPad: Bool {
        get {
            return UIDevice.current.userInterfaceIdiom == .pad
        }
    }
}
