//
//  DataViewController.swift
//  YellAtPeopleWhoViolateSocialDistancing
//
//  Created by Benjamin Bond on 8/26/20.
//  Copyright © 2020 Ben Bond. All rights reserved.
//

import UIKit

class DataViewController : UIViewController, UIPickerViewDelegate, UIPickerViewDataSource, UITextFieldDelegate {

    var pickerData: [[String]] = [["Height:"], []]
    static var chosenFeet = "5"
    static var chosenInches = "7"
    static var chosenRow = 67
    static let shoulderBodyProportion = 0.82
    static var useHumanHeight = true

    
    @IBOutlet weak var segmentedControlButton: UISegmentedControl!
    
    @IBAction func changeSegmentedControl(_ sender: UISegmentedControl) {
        switch segmentedControlButton.selectedSegmentIndex {
            case 0:
                DataViewController.useHumanHeight = true
            case 1:
                DataViewController.useHumanHeight = false
            default:
                DataViewController.useHumanHeight = true
        }
    }
    
    @IBOutlet weak var heightPicker: UIPickerView!
    @IBOutlet weak var heightStackView: UIStackView!
    
    @IBOutlet weak var goBack: UIButton!

    @IBOutlet weak var sayThisTextField: UITextField!
    static var sayThisText = "Social distancing is for your safety. I haven't showered in weeks."
    

    @IBAction func goBack(_ sender: UIButton) {
        dismiss(animated: true, completion: nil)
    }
    @IBAction func textFieldChanged(_ sender: UITextField) {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        DataViewController.sayThisText = self.sayThisTextField.text ?? ""
        textField.resignFirstResponder()
        return true
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.heightPicker.delegate = self
        self.heightPicker.dataSource = self
        self.sayThisTextField.delegate = self
        self.sayThisTextField.placeholder = DataViewController.sayThisText
        for feet in 0...7 {
            for inches in 0...11 {
                pickerData[1].append("\(feet)'\(inches)\"")
            }
        }
        if DataViewController.useHumanHeight {
            segmentedControlButton.selectedSegmentIndex = 0
        } else {
            segmentedControlButton.selectedSegmentIndex = 1
        }
        self.heightPicker.selectRow(DataViewController.chosenRow, inComponent: 1, animated: false)
    
    }
    

    // Number of columns of data
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 2
    }
    
    // The number of rows of data
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        if (component == 0) {
            return 1
        } else {
            return pickerData[1].count
        }
    }
    
    // The data to return for the row and component (column) that's being passed in
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return pickerData[component][row]
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        DataViewController.chosenRow = row
        let val = pickerData[component][row]
        let valArr = val.components(separatedBy: "'")
        DataViewController.chosenFeet = valArr[0]
        DataViewController.chosenInches = String(valArr[1].dropLast())
    }
 
    func pickerView(pickerView: UIPickerView, widthForComponent component: Int) -> CGFloat {
    return 1.0
}
    
    func getHeight() -> Int {
        var height = (Int(DataViewController.chosenFeet) ?? 0) * 12 + (Int(DataViewController.chosenInches) ?? 0)
        if (DataViewController.useHumanHeight) {
            height = Int(Double(height) * DataViewController.shoulderBodyProportion)
        }
        return height
    }

}
