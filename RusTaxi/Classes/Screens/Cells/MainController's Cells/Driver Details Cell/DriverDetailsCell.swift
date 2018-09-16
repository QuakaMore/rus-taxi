//
//  DriverDetailsCell.swift
//  RusTaxi
//
//  Created by Ruslan Prozhivin on 16.09.2018.
//  Copyright © 2018 App's ID. All rights reserved.
//

import UIKit

class DriverDetailsCell: UITableViewCell {
	@IBOutlet weak var driverImageView: UIImageView!
	@IBOutlet weak var nameLabel: UILabel!
	@IBOutlet weak var carLabel: UILabel!
	@IBOutlet weak var carColorLabel: UILabel!
	@IBOutlet weak var callButton: UIButton!
	
	override func awakeFromNib() {
		super.awakeFromNib()
		
		customizeImage()
		customizeButton()
	}
	
	private func customizeButton() {
		callButton.layer.cornerRadius = 0.5 * callButton.bounds.size.width
		callButton.clipsToBounds = true
	}
	
	private func customizeImage() {
		driverImageView.layer.masksToBounds = false
		driverImageView.layer.cornerRadius = driverImageView.frame.height / 2
		driverImageView.clipsToBounds = true
	}
}