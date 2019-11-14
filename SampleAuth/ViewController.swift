//
//  ViewController.swift
//  SampleAuth
//
//  Created by Mike Silvis on 11/14/19.
//  Copyright © 2019 Square. All rights reserved.
//

import UIKit
import CoreLocation
import AVFoundation
import SquareReaderSDK

class ViewController: UIViewController {

    private lazy var locationManager = CLLocationManager()

    private let accessToken: String = "<# replace me #>"
    private let apiURL: String = "https://connect.squareup.com/mobile/authorization-code"
    private let locationID: String = "<# replace me #>"

    private var authorization_code: String = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        view.accessibilityIdentifier = "MainView"

        requestLocationPermission()
        requestMicrophonePermission()

        let button = UIButton(frame: CGRect(x: 100, y: 100, width: 200, height: 200))
        button.layer.cornerRadius = 0.5 * button.bounds.size.width
        button.center = self.view.center
        button.backgroundColor = UIColor(red:0.32, green:0.36, blue:0.70, alpha:0.4)
        button.isEnabled = false
        button.setTitle("Loading...", for: .normal)
        button.addTarget(self, action: #selector(buttonAction), for: .touchUpInside)

        self.view.addSubview(button)

        let apiurl = URL(string: apiURL)
        var request = URLRequest(url: apiurl!)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        let json: [String: Any] = ["location_id": locationID]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        request.httpBody = jsonData
        URLSession.shared.dataTask(with: request) { (data, response, error)   in
            if ((response as? HTTPURLResponse) != nil && data != nil) {
                do {
                    let jsonData = try JSONSerialization.jsonObject(with: data!, options: .mutableContainers) as! NSDictionary
                    self.authorization_code = jsonData["authorization_code"] as! String
                    DispatchQueue.main.async {
                        button.isEnabled = true
                        button.setTitle("Payment", for: .normal)
                        button.backgroundColor = UIColor(red:0.32, green:0.36, blue:0.70, alpha:1.0)
                    }
                } catch {
                    print("Error in parsing")
                }
            }else{
                print("Error: \(String(describing: error))")
            }
        }.resume()
    }

    @objc func buttonAction(sender: UIButton!){
        authorizeReaderSDKIfNeeded()
        startCheckout()
    }

    func requestLocationPermission() {
        switch CLLocationManager.authorizationStatus() {
        case .notDetermined:
            self.locationManager.requestWhenInUseAuthorization()
        case .restricted, .denied:
            print("Show UI directing the user to the iOS Settings app")
        case .authorizedAlways, .authorizedWhenInUse:
            print("Location services have already been authorized.")
        @unknown default:
            print("Error")
        }
    }

    func retrieveAuthorizationCode() -> String {
        return self.authorization_code
    }

    func authorizeReaderSDKIfNeeded() {

        if SQRDReaderSDK.shared.isAuthorized {
            print("Already authorized.")
        }
        else {
            let authCode = retrieveAuthorizationCode()

            SQRDReaderSDK.shared.authorize(withCode: authCode) { location, error in

                if let authError = error {
                    // Handle the error
                    print(authError)
                }
                else {
                    // Proceed to the main application interface.
                }
            }
        }
    }

}

extension ViewController {

    func requestMicrophonePermission() {
        // Note: The microphone permission prompt will not be displayed
        // when running on the simulator
        AVAudioSession.sharedInstance().requestRecordPermission { authorized in
            if !authorized {
                print("Show UI directing the user to the iOS Settings app")
            }
        }
    }
}

extension ViewController: SQRDCheckoutControllerDelegate {
    func checkoutControllerDidCancel(
        _ checkoutController: SQRDCheckoutController) {
        print("Checkout cancelled.")
    }

    // Success delegate method
    func checkoutController(
        _ checkoutController: SQRDCheckoutController,
        didFinishCheckoutWith result: SQRDCheckoutResult) {
        // result contains details about the completed checkout
        print("Checkout completed: \(result.description).")
    }

    // Failure delegate method
    func checkoutController(
        _ checkoutController: SQRDCheckoutController, didFailWith error: Error) {
        // Checkout controller errors are always of type SQRDCheckoutControllerError
        let checkoutControllerError = error as! SQRDCheckoutControllerError

        switch checkoutControllerError.code {
        case .sdkNotAuthorized:
            // Checkout failed because the SDK is not authorized
            // with a Square merchant account.
            print("Reader SDK is not authorized.")
        case .usageError:
            // Checkout failed due to a usage error. Inspect the userInfo
            // dictionary for additional information.
            if let debugMessage = checkoutControllerError.userInfo[SQRDErrorDebugMessageKey],
                let debugCode = checkoutControllerError.userInfo[SQRDErrorDebugCodeKey] {
                print(debugCode, debugMessage)
            }
        @unknown default:
            print("Error")
        }
    }
}

extension ViewController {
    func startCheckout() {
        // Create an amount of money in the currency of the authorized Square account
        let amountMoney = SQRDMoney(amount: 100)

        // Create parameters to customize the behavior of the checkout flow.
        let params = SQRDCheckoutParameters(amountMoney: amountMoney)
        params.additionalPaymentTypes = [.cash, .manualCardEntry]

        // Create a checkout controller and call present to start checkout flow.
        let checkoutController = SQRDCheckoutController(
            parameters: params,
            delegate: self)
        checkoutController.present(from: self)
    }
}
