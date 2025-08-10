//  GeneralConditionsTip.swift
//  Rheir
//
//  Created by Kevin Barrett on 5/4/25.
//

import SwiftUI
import TipKit

struct GeneralConditionsTip: Tip {
  var title: Text { Text("General Conditions") }
  var message: Text? { Text("Includes expenses like mileage, consumables, and additional costs.") }
  var image: Image? { Image(systemName: "info.circle") }
}
