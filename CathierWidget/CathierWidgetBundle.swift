//
//  CathierWidgetBundle.swift
//  CathierWidget
//
//  Created by Jianshuo Wang on 2026/4/5.
//

import WidgetKit
import SwiftUI

@main
struct CathierWidgetBundle: WidgetBundle {
    var body: some Widget {
        CathierWidget()
        CathierWidgetControl()
        CathierWidgetLiveActivity()
    }
}
