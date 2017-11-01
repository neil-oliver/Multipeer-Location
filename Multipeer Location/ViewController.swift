import UIKit
import MultipeerConnectivity
import CoreLocation
import CoreBluetooth
import MapKit
import QuartzCore


class ViewController: UIViewController, MCBrowserViewControllerDelegate, MCSessionDelegate, CBPeripheralManagerDelegate, CLLocationManagerDelegate, MKMapViewDelegate {
    
    let serviceType = "LCOC-Chat"
    
    var browser : MCBrowserViewController!
    var assistant : MCAdvertiserAssistant!
    var session : MCSession!
    var peerID: MCPeerID!
    
    /*
    struct sendLocation {
    var peerID: MCPeerID!
    var location: CLLocation!
    }
    */
    
    @objc(sendLocation) class sendLocation: NSObject, NSCoding {
        
        var peerID: MCPeerID!
        var location: CLLocation!
        
        init(peerID: MCPeerID, location: CLLocation) {
            self.peerID = peerID
            self.location = location
        }
        
        required init(coder aDecoder: NSCoder) {
            peerID = aDecoder.decodeObject(forKey: "peerID") as! MCPeerID
            location = aDecoder.decodeObject(forKey: "location") as! CLLocation
        }
        
        func encode(with aCoder: NSCoder) {
            aCoder.encode(peerID, forKey: "peerID")
            aCoder.encode(location, forKey: "location")
        }
    }
    
    @objc(OPLocationAnnotation) class OPLocationAnnotation : NSObject, MKAnnotation {
        var coordinate: CLLocationCoordinate2D
        var title: String?
        var accuracy: CLLocationAccuracy?
        
        init(coordinate: CLLocationCoordinate2D, title: String, accuracy: CLLocationAccuracy) {
            self.coordinate = coordinate
            self.title = title
            self.accuracy = accuracy
        }
    }
    
    @IBOutlet var chatView: UITextView!
    @IBOutlet var messageField: UITextField!
    @IBOutlet var iBeaconView: UITextView!
    @IBOutlet var distanceView: UITextView!

    
    let locationManager = CLLocationManager()

    
    @IBAction func getLocation(_ sender:UIButton) {
        if locationManager.location != nil {
           locationManager.startUpdatingLocation()
        } else {
            messageField.text = "No Location Data Available"
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        locationManager.delegate = self
        map.delegate = self
        map.showsUserLocation = true

        if locationManager.location != nil {
            let region = MKCoordinateRegionMakeWithDistance((locationManager.location?.coordinate)!, 500, 500)
            map.setRegion(region, animated: true)
            //let OP = OPLocationAnnotation(coordinate: (locationManager.location?.coordinate)! , title: "OP")
            
            //self.map.addAnnotation(OP)
        }
        
        initLocalBeacon()
        
        self.peerID = MCPeerID(displayName: UIDevice.current.name)
        self.session = MCSession(peer: peerID)
        self.session.delegate = self
        
        // create the browser viewcontroller with a unique service name
        self.browser = MCBrowserViewController(serviceType:serviceType, session:self.session)
        
        self.browser.delegate = self;
        
        self.assistant = MCAdvertiserAssistant(serviceType:serviceType, discoveryInfo:nil, session:self.session)
        
        // tell the assistant to start advertising our fabulous chat
        self.assistant.start()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        print("Location updated")
        let location = locations.last
        print(location!)
        let sendObject = sendLocation(peerID: peerID, location: location!)

        NSKeyedArchiver.setClassName("sendLocation", for: sendLocation.self)
        let locationData = NSKeyedArchiver.archivedData(withRootObject: sendObject)
        do {
            try self.session.send(locationData, toPeers: self.session.connectedPeers, with: MCSessionSendDataMode.unreliable)
        } catch {
            print("Error sending data: \(error.localizedDescription)")
        }
    }

    
    @IBAction func showBrowser(_ sender: UIButton) {
        // Show the browser view controller
        self.present(self.browser, animated: true, completion: nil)
    }
    
    func browserViewControllerDidFinish(
        _ browserViewController: MCBrowserViewController)  {
        // Called when the browser view controller is dismissed (ie the Done
        // button was tapped)
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func browserViewControllerWasCancelled(
        _ browserViewController: MCBrowserViewController)  {
        // Called when the browser view controller is cancelled
        
        self.dismiss(animated: true, completion: nil)
    }
    
    func session(_ session: MCSession, didReceive data: Data,
                 fromPeer peerID: MCPeerID)  {
        // Called when a peer sends an NSData to us
        
        // This needs to run on the main queue
        DispatchQueue.main.async {
            print("data \(data)")
            NSKeyedUnarchiver.setClass(sendLocation.self, forClassName: "sendLocation")
            let locationData = NSKeyedUnarchiver.unarchiveObject(with: data)  as! sendLocation
            self.chatView.text = "\(locationData.location!) \n"
            let distance = self.locationManager.location?.distance(from: locationData.location!)
            self.distanceView.text = "GPS Data shows you are \(distance!) meters apart"
            let OP = OPLocationAnnotation(coordinate: locationData.location!.coordinate, title: "OP", accuracy: locationData.location.horizontalAccuracy)
            
            self.map.addAnnotation(OP)
        }
    }
    
    func mapView(_ mapView: MKMapView,viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if (annotation is MKUserLocation) {
            //if annotation is not an MKPointAnnotation (eg. MKUserLocation),
            //return nil so map draws default view for it (eg. blue dot)...
            return nil
        }
        if (annotation is OPLocationAnnotation){
            let reuseId = "OP"
            var anView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseId) as? SVPulsingAnnotationView
            
            if anView == nil {
                anView = SVPulsingAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
                anView?.annotationColor = UIColor(colorLiteralRed: 0.678431, green: 0, blue: 0, alpha: 1)
                anView?.pulseScaleFactor = 1
                anView?.canShowCallout = false
            } else {
                //we are re-using a view, update its annotation reference...
                anView?.annotation = annotation
            }
            
            return anView
        }
        return nil
    }

    
    // The following methods do nothing, but the MCSessionDelegate protocol
    // requires that we implement them.
    func session(_ session: MCSession,
                 didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress)  {
        
        // Called when a peer starts sending a file to us
    }
    
    func session(_ session: MCSession,
                 didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID,
                 at localURL: URL?, withError error: Error?)  {
        // Called when a file has finished transferring from another peer
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream,
                 withName streamName: String, fromPeer peerID: MCPeerID)  {
        // Called when a peer establishes a stream with us
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID,
                 didChange state: MCSessionState)  {
        // Called when a connected peer changes state (for example, goes offline)
        
    }
    
    
    //iBeacon Broadcast Code
    
    var localBeacon: CLBeaconRegion!
    var beaconPeripheralData: NSDictionary!
    var peripheralManager: CBPeripheralManager!
    
    func initLocalBeacon() {
        if localBeacon != nil {
            stopLocalBeacon()
        }
        
        let localBeaconUUID = "5A4BCFCE-174E-4BAC-A814-092E77F6B7E5"
        let localBeaconMajor: CLBeaconMajorValue = 123
        let localBeaconMinor: CLBeaconMinorValue = 456
        
        let uuid = UUID(uuidString: localBeaconUUID)!
        localBeacon = CLBeaconRegion(proximityUUID: uuid, major: localBeaconMajor, minor: localBeaconMinor, identifier: "Neil-Oliver.Multipeer-Location")
        
        beaconPeripheralData = localBeacon.peripheralData(withMeasuredPower: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil, options: nil)
    }
    
    func stopLocalBeacon() {
        peripheralManager.stopAdvertising()
        peripheralManager = nil
        beaconPeripheralData = nil
        localBeacon = nil
    }
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {

        if peripheral.state == .poweredOn {
            peripheralManager.startAdvertising(beaconPeripheralData as! [String: AnyObject]!)
        } else if peripheral.state == .poweredOff {
            peripheralManager.stopAdvertising()
        }
    }
    
    //iBeacon Detection
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {

        if status == .authorizedAlways {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
                    startScanning()
                }
            }
        }
    }
    
    func startScanning() {

        let uuid = UUID(uuidString: "5A4BCFCE-174E-4BAC-A814-092E77F6B7E5")!
        let beaconRegion = CLBeaconRegion(proximityUUID: uuid, major: 123, minor: 456, identifier: "Neil-Oliver.Multipeer-Location")
        
        locationManager.startMonitoring(for: beaconRegion)
        locationManager.startRangingBeacons(in: beaconRegion)
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if beacons.count > 0 {
            updateDistance(beacons[0].proximity)
            if beacons[0].proximity != .unknown {
                self.iBeaconView.text = "iBeacon Data shows you are \(beacons[0].accuracy) meters apart"
            } else {
                self.iBeaconView.text = "Phone no longer in range of bluetooth"
            }
        } else {
            updateDistance(.unknown)
        }
    }
    
    func updateDistance(_ distance: CLProximity) {
        UIView.animate(withDuration: 0.8) {
            switch distance {
            case .unknown:
                self.view.backgroundColor = UIColor.gray
                
            case .far:
                self.view.backgroundColor = UIColor.red
                
            case .near:
                self.view.backgroundColor = UIColor.orange
                
            case .immediate:
                self.view.backgroundColor = UIColor.green
            }
        }
    }
    
    
    //map
    @IBOutlet var map: MKMapView!
    
    

}
