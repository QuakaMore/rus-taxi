//
//  StartDataSource.swift
//  RusTaxi
//
//  Created by Ruslan Prozhivin on 15.09.2018.
//  Copyright © 2018 App's ID. All rights reserved.
//

import UIKit

@objc protocol MainDataSource: class, UITableViewDelegate, UITableViewDataSource {
	var scrollViewScrolled: ScrollViewClosure? { get set}
	func update(with models: [Any])
}

protocol LoaderDataSource: MainDataSource {
	var viewController: MainController? { get set }
}

extension LoaderDataSource {
	func startLoading() {
		guard let tableView = viewController?.tableView else {
			return
		}
		
		if let cell = tableView.cellForRow(at: IndexPath.init(row: 0, section: 0)) as? HeaderCell {
			cell.startLoading()
		}
	}
	
	func stopLoading() {
		guard let tableView = viewController?.tableView else {
			return
		}
		
		if let cell = tableView.cellForRow(at: IndexPath.init(row: 0, section: 0)) as? HeaderCell {
			cell.stopLoading()
		}
	}
}

class MainControllerDataSource: NSObject, LoaderDataSource {
	typealias ModelType = Address
	private var models: [Address]
	var viewController: MainController?
	// callbacks
	var currentLocationClicked: VoidClosure?
	var actionAddClicked: VoidClosure?
	var deleteCellClicked: ViewClosure?
	var orderTimeClicked: VoidClosure?
	var payTypeClicked: VoidClosure?
	var wishesClicked: VoidClosure?
	var subviewsLayouted: VoidClosure?
	var pushClicked: ItemClosure<Int>?
	var scrollViewScrolled: ScrollViewClosure?
	var scrollViewDragged: ScrollViewClosure?
	//
	
	required init(models: [Address]) {
		self.models = models
		super.init()
	}
	
	@objc private func currentLocationAction() {
		currentLocationClicked?()
	}
	
	@objc private func deleteCellAction(sender: UIButton) {
		deleteCellClicked?(sender)
	}
	
	@objc private func actionButtonAdd() {
		actionAddClicked?()
	}
	
	@objc private func payTypeAction() {
		payTypeClicked?()
	}
	
	func scrollViewDidScroll(_ scrollView: UIScrollView) {
		self.scrollViewScrolled?(scrollView)
	}
	
	func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
		subviewsLayouted?()
	}
	
	func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		if indexPath.row == 0 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "headCell", for: indexPath) as! HeaderCell
			let lastResponse = OrderManager.shared.lastPrecalculateResponse
			if let dist = lastResponse?.dist, let time = lastResponse?.time {
				cell.label.text = "~\(dist) мин. \(time)км."
			} else {
				cell.label.text = nil
			}
			cell.indicator.startProgressing()
			cell.myPositionButton.setImage(UIImage(named: "ic_menu_mylocation"), for: .normal)
			cell.myPositionButton.isHidden = false
			cell.myPositionView.isHidden = false
			cell.myPositionView.backgroundColor = TaxiColor.white
			cell.myPositionButton.addTarget(self, action: #selector(currentLocationAction), for: .touchUpInside)
			return cell
		} else if indexPath.row > 0 && indexPath.row <= models.count {
			let cell = tableView.dequeueReusableCell(withIdentifier: "addressCell", for: indexPath) as! AddressCell
			let model = models[indexPath.row - 1]
			cell.configure(by: model)
			cell.addressTextField.isEnabled = false
			cell.topLineView.isHidden = model.position == .top
			cell.botLineView.isHidden = model.pointName == models.last!.pointName
			switch model.state {
			case .default:
				cell.actionButton.isHidden = true
			case .add:
				cell.actionButton.isHidden = false
				cell.actionButton.setImage(icons[0], for: .normal)
				cell.actionButton.removeTarget(self, action: nil, for: .allEvents)
				cell.actionButton.addTarget(self, action: #selector(actionButtonAdd), for: .touchUpInside)
			default:
				cell.actionButton.isHidden = false
				cell.actionButton.removeTarget(self, action: nil, for: .allEvents)
				cell.actionButton.setImage(icons[1], for: .normal)
				cell.actionButton.addTarget(self, action: #selector(deleteCellAction), for: .touchUpInside)
			}
			return cell
		} else if indexPath.row == models.count + 1 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "settingsCell", for: indexPath) as! SettingsCell
			let bookingTime = NewOrderDataProvider.shared.request.booking_time
			let secondPart = bookingTime?.split(separator: "T")[1] ?? ""
			
			let dateFormatter = DateFormatter.init()
			dateFormatter.dateFormat = "HH:mm:ss"
			let date = dateFormatter.date(from: String(secondPart))
			let isNearTimeSelected = (NewOrderDataProvider.shared.request.nearest ?? false)
			if isNearTimeSelected {
				cell.orderTimeButton.setTitle(Localize("now"), for: .normal)
			} else {
				if let unboxDate = date {
					cell.orderTimeButton.setTitle(unboxDate.convertFormateToNormDateString(format: "HH:mm"), for: .normal)
				}
			}
			cell.orderTimeClicked = orderTimeClicked
			cell.wishesButton.setTitle("(\(NewOrderDataProvider.shared.request.requirements?.count ?? 0))", for: .normal)
			cell.payTypeButton.addTarget(self, action: #selector(payTypeAction), for: .touchUpInside)
			cell.wishesClicked = self.wishesClicked
			cell.priceTextField.addTarget(self, action: #selector(priceTextFieldChanged(sender:)), for: .editingChanged)
 			cell.priceTextField.underline()
			return cell
		} else if indexPath.row == models.count + 2 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "chooseTaxiCell", for: indexPath) as! ChooseTaxiCell
			return cell
		} else if indexPath.row == models.count + 3 {
			let cell = tableView.dequeueReusableCell(withIdentifier: "callTaxiCell", for: indexPath) as! CallTaxiCell
			func setTitleForSelectedTariff(tariff: String) {
				if let money = NewOrderDataProvider.shared.request.auction_money, money > 0 {
					cell.callButton.setTitle("ПРЕДЛОЖИТЬ ЦЕНУ\n\(money)₽", for: .normal)
					return
				}
				guard let lastResponse = UserManager.shared.lastResponse else {
					return
				}
				
				let tariffs = lastResponse.tariffs ?? []
				
				let selectedTariff = tariffs.first(where: { (response) -> Bool in
					return response.uuid == tariff
				})
				
				let tariffName = selectedTariff?.name ?? Localize("taxi")
				cell.callButton.backgroundColor = TaxiColor.taxiOrange
				cell.callButton.titleLabel?.font = TaxiFont.helveticaMedium
				
				if let lastResponse = OrderManager.shared.lastPrecalculateResponse, (Double(lastResponse.money_o ?? "") ?? 0) > 0 {
					cell.callButton.setTitle("ЗАКАЗАТЬ\n~\(lastResponse.money_o ?? "")₽ \(tariffName.uppercased())", for: .normal)
				} else {
					if let tariff = selectedTariff {					
						cell.callButton.setTitle("ЗАКАЗАТЬ\n\(tariff.name ?? "")", for: .normal)
					} else {
						cell.callButton.setTitle("ЗАКАЗАТЬ\n\(lastResponse.tariffs?.first?.name ?? "")", for: .normal)
					}
				}
			}
			
			NewOrderDataProvider.shared.tariffChanged = { tariff in
				setTitleForSelectedTariff(tariff: tariff)
			}
			
			NewOrderDataProvider.shared.priceChanged = { price in
				setTitleForSelectedTariff(tariff: "")
			}
			
			setTitleForSelectedTariff(tariff: UserManager.shared.lastResponse?.tariffs?.first?.name ?? "")
			cell.callButtonClicked = {
				let isFilled = NewOrderDataProvider.shared.isFilled()
				
				guard isFilled else {
					self.viewController?.showAlert(title: Localize("error"), message: Localize("fullFields"))
					return
				}
				
				NewOrderDataProvider.shared.post(with: { (response) in
					let message = response?.err_txt ?? ""
					if response?.Status == "Published" {
						Toast.hide()
						Toast.show(with: message, timeline: Time(4))
						self.viewController?.set(dataSource: .search)
						let orderId = response?.local_id ?? ""
						let status = response?.Status ?? ""
						MapDataProvider.shared.startCheckingOrder(order_id: orderId, order_status: status)
					} else {
						self.viewController?.showAlert(title: Localize("error"), message: message)
					}
				})
				
			}
			return cell
		}
		return UITableViewCell()
	}
	
	@objc private func priceTextFieldChanged(sender: UITextField) {
		let intPrice = Int(sender.text ?? "") ?? 0
		
		let price = Double(intPrice)
		NewOrderDataProvider.shared.change(price: price)
	}
	
	
	func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
		scrollViewDragged?(scrollView)
	}
	
	func update(with models: [Any]) {
		if let addressModels = models as? [Address] {
			self.models = addressModels
		}
	}
	
	func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		if indexPath.row > 0 && indexPath.row <= models.count {
			pushClicked?(indexPath.row - 1)
		}
	}
	
	func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		if indexPath.row == 0 {
			return 45
		} else if indexPath.row > 0 && indexPath.row <= models.count {
			return 50
		} else if indexPath.row == models.count + 1 {
			return 41
		} else if indexPath.row == models.count + 2 {
			return 76
		} else {
			return 48
		}
	}
	
	func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return models.count + 4
	}
}
