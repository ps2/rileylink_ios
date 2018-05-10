//
//  CommandResponseViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit
import os.log


class CommandResponseViewController: UIViewController {
    typealias Command = (_ completionHandler: @escaping (_ responseText: String) -> Void) -> String

    init(command: @escaping Command) {
        self.command = command

        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public var fileName: String?

    private let uuid = UUID()

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
        let title = fileName ?? "\(self.title ?? uuid.uuidString).txt"

        guard let item = SharedResponse(text: textView.text, title: title) else {
            return
        }

        let activityVC = UIActivityViewController(activityItems: [item], applicationActivities: nil)

        present(activityVC, animated: true, completion: nil)
    }
}


private class SharedResponse: NSObject, UIActivityItemSource {

    let title: String
    let fileURL: URL

    init?(text: String, title: String) {
        self.title = title

        var url = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        url.appendPathComponent(title, isDirectory: false)

        do {
            try text.write(to: url, atomically: true, encoding: .utf8)
        } catch let error {
            os_log("Failed to write to file %{public}@: %{public}@", log: .default, type: .error, title, String(describing: error))
            return nil
        }

        fileURL = url

        super.init()
    }

    public func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType?) -> Any? {
        return fileURL
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return title
    }

    public func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivityType?) -> String {
        return "public.utf8-plain-text"
    }
}
