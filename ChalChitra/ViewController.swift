//
//  ViewController.swift
//  ChalChitra
//
//  Created by Kunal Kamble on 12/10/24.
//

import OSLog
import TinyConstraints


class ViewController: UIViewController {
    
    lazy var chalChitra = ChalChitra(url: URL(string: "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8")!, playerHeight: 250)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.addSubview(chalChitra)
        chalChitra.edgesToSuperview(usingSafeArea: true)
    }
    
}
