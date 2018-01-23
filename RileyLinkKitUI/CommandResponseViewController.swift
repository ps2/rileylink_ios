//
//  CommandResponseViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit


class CommandResponseViewController: UIViewController {
    typealias Command = (_ completionHandler: @escaping (_ responseText: String) -> Void) -> String

    init(command: @escaping Command) {
        self.command = command

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private let command: Command

    private lazy var textView = UITextView()

    override func loadView() {
        self.view = textView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        if #available(iOS 11.0, *) {
            textView.contentInsetAdjustmentBehavior = .always
        }

        let font = UIFont(name: "Menlo-Regular", size: 14)
        if #available(iOS 11.0, *), let font = font {
            let metrics = UIFontMetrics(forTextStyle: .body)
            textView.font = metrics.scaledFont(for: font)
        } else {
            textView.font = font
        }

        textView.text = command { [weak self] (responseText) -> Void in
            var newText = self?.textView.text ?? ""
            newText += "\n\n"
            newText += responseText
            self?.textView.text = newText
        }
        textView.isEditable = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareText(_:)))
    }

    @objc func shareText(_: AnyObject?) {
        let activityVC = UIActivityViewController(activityItems: [self], applicationActivities: nil)

        present(activityVC, animated: true, completion: nil)
    }
}

extension CommandResponseViewController: UIActivityItemSource {
    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return title ?? textView.text ?? ""
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType?) -> Any? {
        return textView.attributedText ?? ""
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return title ?? textView.text
    }
}
