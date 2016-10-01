//
//  CommandResponseViewController.swift
//  Naterade
//
//  Created by Nathan Racklyeft on 3/5/16.
//  Copyright © 2016 Nathan Racklyeft. All rights reserved.
//

import UIKit

class CommandResponseViewController: UIViewController, UIActivityItemSource {
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

        textView.font = UIFont(name: "Menlo-Regular", size: 14)
        textView.text = command { [weak self] (responseText) -> Void in
            self?.textView.text = responseText
        }
        textView.isEditable = false

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .action, target: self, action: #selector(shareText(_:)))
    }

    @objc func shareText(_: AnyObject?) {
        let activityVC = UIActivityViewController(activityItems: [self], applicationActivities: nil)

        present(activityVC, animated: true, completion: nil)
    }

    // MARK: - UIActivityItemSource

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return title ?? textView.text ?? ""
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivityType) -> Any? {
        return textView.attributedText
    }

    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivityType?) -> String {
        return title ?? textView.text ?? ""
    }
}
