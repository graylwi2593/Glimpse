// MapViewController.swift

import UIKit
import MapKit
import CoreLocation
import Cloudinary

class MapViewController: UIViewController, CLLocationManagerDelegate, MKMapViewDelegate {
    
    // MARK: - Variables
    private var mapView: MKMapView!
    private var locationManager: CLLocationManager!
    private let mapVM = MapViewModel()
    private var updateTimer: Timer?
    private var isInitialLocationSet = false
    
    private var userImage: String?
    private var userName: String?
    
    private var userAnnotation: MKPointAnnotation?
    private var friendAnnotations: [MKPointAnnotation] = []
    
    private var addGlimpseButton: UIButton!
    private var activityIndicator: UIActivityIndicatorView?
    private var activityIndicatorContainer: UIView?
    
    
    
    // MARK: - LifeCycle
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMap()
        fetchUserInfo()
        setupAddGlimpseButton()
        setupLocationManager()
        setupNotificationObserver()
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchAndUpdateFriendsLocations()
        }
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.fetchAndUpdateFriendsLocations()
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .didLogout, object: nil)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        fetchAndUpdateFriendsLocations()
        fetchUserInfo()
    }
    
    
    // MARK: - Setup
    private func setupMap() {
        mapView = MKMapView(frame: view.bounds)
        mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        mapView.delegate = self
        mapView.showsUserLocation = false
        view.addSubview(mapView)
    }
    
    private func setupLocationManager() {
        locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.startUpdatingLocation()
            updateTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(updateLocationPeriodically), userInfo: nil, repeats: true)
        } else {
            print("Location services are not enabled")
        }
    }
    
    private func setupAddGlimpseButton() {
        addGlimpseButton = UIButton(type: .custom)
        addGlimpseButton.frame = CGRect(x: 0, y: 0, width: 60, height: 60)
        addGlimpseButton.layer.cornerRadius = 30
        addGlimpseButton.setImage(UIImage(systemName: "plus"), for: .normal)
        addGlimpseButton.tintColor = .white
        addGlimpseButton.imageView?.contentMode = .scaleAspectFit
        addGlimpseButton.backgroundColor = UIColor(red: 0.16, green: 0.5, blue: 0.73, alpha: 1.0)
        addGlimpseButton.addTarget(self, action: #selector(addButtonTapped), for: .touchUpInside)
        
        addGlimpseButton.layer.shadowColor = UIColor.black.cgColor
        addGlimpseButton.layer.shadowOffset = CGSize(width: 0, height: 2)
        addGlimpseButton.layer.shadowRadius = 4
        addGlimpseButton.layer.shadowOpacity = 0.3
        
        view.addSubview(addGlimpseButton)
        
        addGlimpseButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            addGlimpseButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            addGlimpseButton.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -20),
            addGlimpseButton.widthAnchor.constraint(equalToConstant: 60),
            addGlimpseButton.heightAnchor.constraint(equalToConstant: 60)
        ])
    }
    
    @objc private func addButtonTapped() {
        print("Add button tapped")
        openCamera()
    }
    
    private func openCamera(){
        
        
        if UIImagePickerController.isSourceTypeAvailable(.camera){
            let imagePickerController = UIImagePickerController()
            imagePickerController.delegate = self
            imagePickerController.sourceType = .camera
            imagePickerController.allowsEditing = false
            self.present(imagePickerController, animated: true, completion: nil)
        }
        else {
            let alert = UIAlertController(title: "Error", message: "Camera is not available in this device", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
            self.present(alert, animated: true, completion: nil)
        }
    }
    
    private func setupNotificationObserver() {
        NotificationCenter.default.addObserver(self, selector: #selector(handleLogoutNotification), name: .didLogout, object: nil)
    }
    
    // MARK: - Helper Methods
    private func fetchUserInfo() {
        mapVM.getUserInfoByToken { [weak self] user in
            DispatchQueue.main.async {
                if let user = user {
                    self?.userName = user.username
                    print("Fetched username: \(self?.userName ?? "No username")")
                    self?.userImage = user.image
                    self?.updateUserAnnotation()
                } else {
                    print("Failed to fetch user info.")
                }
            }
        }
    }
    
    private func updateUserAnnotation() {
        if let userAnnotation = userAnnotation {
            userAnnotation.title = userName
            mapView.removeAnnotation(userAnnotation)
        } else {
            userAnnotation = MKPointAnnotation()
            userAnnotation?.title = userName
        }
        mapView.addAnnotation(userAnnotation!)
    }
    
    
    // MARK: - Location Management
    private func updateUserLocation(latitude: Double, longitude: Double) {
        guard let token = UserDefaults.standard.string(forKey: "authToken") else {
            print("Token not found")
            return
        }
        
        mapVM.updateLocation(token: token, latitude: latitude, longitude: longitude) { success, message in
            DispatchQueue.main.async {
                if success {
                    print("Location updated successfully")
                } else {
                    print("Failed to update location: \(message ?? "No message")")
                }
            }
        }
    }
    private func updateMapLocation(latitude: Double, longitude: Double) {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
        if userAnnotation == nil {
            userAnnotation = MKPointAnnotation()
            userAnnotation?.title = userName
            mapView.addAnnotation(userAnnotation!)
        }
        
        userAnnotation?.coordinate = coordinate
        
        if let annotationView = mapView.view(for: userAnnotation!) {
            updateAnnotationView(annotationView)
        }
    }
    
    
    @objc private func updateLocationPeriodically() {
        if let location = locationManager.location {
            let latitude = location.coordinate.latitude
            let longitude = location.coordinate.longitude
            updateUserLocation(latitude: latitude, longitude: longitude)
            updateMapLocation(latitude: latitude, longitude: longitude)
        }
    }
    
    private func stopLocationUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        locationManager.stopUpdatingLocation()
    }
    // MARK: - Friends Location
    private func fetchAndUpdateFriendsLocations() {
        mapVM.fetchFriendsLocation { [weak self] friends in
            DispatchQueue.main.async {
                self?.updateFriendsAnnotations(friends)
            }
        }
    }
    
    private func updateFriendsAnnotations(_ friends: [[String: Any]]?) {
        mapView.removeAnnotations(friendAnnotations)
        friendAnnotations.removeAll()
        
        guard let friends = friends else { return }
        
        for friend in friends {
            if let latitude = friend["latitude"] as? Double,
               let longitude = friend["longitude"] as? Double,
               let username = friend["username"] as? String,
               let imageUrl = friend["image"] as? String {
                let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                
                if userAnnotation?.coordinate.latitude != latitude || userAnnotation?.coordinate.longitude != longitude {
                    let annotation = MKPointAnnotation()
                    annotation.coordinate = coordinate
                    annotation.title = username
                    annotation.subtitle = imageUrl
                    friendAnnotations.append(annotation)
                }
            }
        }
        mapView.addAnnotations(friendAnnotations)
    }
    
    // MARK: - Notification Handlers
    @objc private func handleLogoutNotification() {
        stopLocationUpdates()
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        let latitude = location.coordinate.latitude
        let longitude = location.coordinate.longitude
        
        if !isInitialLocationSet {
            let region = MKCoordinateRegion(center: location.coordinate, latitudinalMeters: 1000, longitudinalMeters: 1000)
            mapView.setRegion(region, animated: true)
            isInitialLocationSet = true
        }
        
        updateUserLocation(latitude: latitude, longitude: longitude)
        updateMapLocation(latitude: latitude, longitude: longitude)
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Failed to find user's location: \(error.localizedDescription)")
    }
    
    // MARK: - MKMapViewDelegate
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        let reuseID = annotation === userAnnotation ? "userAnnotation" : "friendAnnotation"
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseID)
        
        if annotationView == nil {
            annotationView = MKAnnotationView(annotation: annotation, reuseIdentifier: reuseID)
            annotationView?.canShowCallout = true
        } else {
            annotationView?.annotation = annotation
        }
        
        if annotation === userAnnotation {
            configureUserAnnotation(annotationView)
        } else {
            configureFriendAnnotation(annotationView)
        }
        
        return annotationView
    }
    
    private func configureUserAnnotation(_ annotationView: MKAnnotationView?) {
        let containerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 60, height: 80)))
        containerView.tag = 100
        
        let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 60, height: 60)))
        imageView.contentMode = .scaleAspectFill
        imageView.layer.cornerRadius = 30
        imageView.clipsToBounds = true
        imageView.layer.borderWidth = 3
        imageView.contentMode = .scaleToFill
        imageView.layer.borderColor = UIColor(hex: "43D53E").cgColor
        containerView.addSubview(imageView)
        
        let label = UILabel(frame: CGRect(x: 0, y: 62, width: 60, height: 18))
        label.text = userName
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.5
        containerView.addSubview(label)
        
        annotationView?.addSubview(containerView)
        annotationView?.frame.size = containerView.frame.size
        
        if let imageUrl = userImage {
            imageView.downloaded(from: imageUrl)
        } else {
            imageView.image = UIImage(named: "defaultavatar")
        }
    }
    
    
    private func configureFriendAnnotation(_ annotationView: MKAnnotationView?) {
        var containerView = annotationView?.viewWithTag(100) as? UIView
        if containerView == nil {
            containerView = UIView(frame: CGRect(origin: .zero, size: CGSize(width: 60, height: 80)))
            containerView!.tag = 100
            
            let imageView = UIImageView(frame: CGRect(origin: .zero, size: CGSize(width: 60, height: 60)))
            imageView.contentMode = .scaleAspectFill
            imageView.layer.cornerRadius = 30
            imageView.clipsToBounds = true
            imageView.layer.borderWidth = 2
            imageView.contentMode = .scaleToFill
            imageView.layer.borderColor = UIColor(hex: "4a7eba").cgColor
            containerView!.addSubview(imageView)
            
            let label = UILabel(frame: CGRect(x: 0, y: 62, width: 60, height: 18))
            label.textAlignment = .center
            label.font = UIFont.systemFont(ofSize: 14, weight: .semibold)
            label.adjustsFontSizeToFitWidth = true
            label.minimumScaleFactor = 0.5
            containerView!.addSubview(label)
            
            annotationView?.addSubview(containerView!)
            annotationView?.frame.size = containerView!.frame.size
        }
        
        if let imageView = containerView?.subviews.first as? UIImageView {
            if let imageUrl = annotationView?.annotation?.subtitle {
                imageView.downloaded(from: imageUrl!)
            } else {
                imageView.image = UIImage(named: "defaultavatar")
            }
        }
        
        if let label = containerView?.subviews.last as? UILabel {
            label.text = annotationView?.annotation?.title ?? "Friend"
        }
    }
    
    private func shouldAnimate(annotationView: MKAnnotationView?) -> Bool {
        return true
    }
    
    private func updateAnnotationView(_ annotationView: MKAnnotationView?) {
        if let containerView = annotationView?.viewWithTag(100) {
            if let imageView = containerView.subviews.first as? UIImageView {
                if let imageUrl = userImage {
                    imageView.downloaded(from: imageUrl)
                } else {
                    imageView.image = UIImage(named: "defaultavatar")
                }
                animateAnnotationView(imageView)
            }
            if let label = containerView.subviews.last as? UILabel {
                label.text = userName
            }
        }
    }
    
    
    private func animateAnnotationView(_ containerView: UIView) {
        containerView.transform = CGAffineTransform(scaleX: 1.0, y: 1.0)
        
        UIView.animate(withDuration: 0.3, animations: {
            containerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        }) { _ in
            UIView.animate(withDuration: 0.3) {
                containerView.transform = CGAffineTransform.identity
            }
        }
        
    }
    
}

extension Notification.Name {
    static let didLogout = Notification.Name("didLogout")
}

extension MapViewController: UIImagePickerControllerDelegate, UINavigationControllerDelegate{
    
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        
        if let image = info[.originalImage] as? UIImage {
            print("\(image)")
            
            let container = UIView()
            container.translatesAutoresizingMaskIntoConstraints = false
            container.backgroundColor = UIColor(white: 0, alpha: 0.7)
            container.layer.cornerRadius = 10
            container.layer.masksToBounds = true
            self.view.addSubview(container)
            self.activityIndicatorContainer = container
            
            NSLayoutConstraint.activate([
                container.centerXAnchor.constraint(equalTo: self.view.centerXAnchor),
                container.centerYAnchor.constraint(equalTo: self.view.centerYAnchor),
                container.widthAnchor.constraint(equalToConstant: 120),
                container.heightAnchor.constraint(equalToConstant: 120)
            ])
            
            let activityIndicator = UIActivityIndicatorView(style: .large)
            activityIndicator.color = .white
            activityIndicator.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(activityIndicator)
            activityIndicator.startAnimating()
            
            NSLayoutConstraint.activate([
                activityIndicator.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                activityIndicator.centerYAnchor.constraint(equalTo: container.centerYAnchor)
            ])
            
            self.view.isUserInteractionEnabled = false
            
            uploadImage(image: image) { [weak self] url in
                DispatchQueue.main.async {
                    if let url = url {
                        print("\(url)")
                        self?.mapVM.uploadGlimpse(image: url)
                        
                        let alert = UIAlertController(title: "Success", message: "Upload glimpse successfully", preferredStyle: .alert)
                        self?.present(alert, animated: true, completion: {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                                alert.dismiss(animated: true, completion: nil)
                            }
                        })
                    } else {
                        print("Can't upload")
                    }
                    
                    self?.activityIndicatorContainer?.removeFromSuperview()
                    self?.view.isUserInteractionEnabled = true
                }
            }
        }
        picker.dismiss(animated: true, completion: nil)
    }
    
    func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
        picker.dismiss(animated: true, completion: nil)
    }
    func uploadImage(image: UIImage, completion: @escaping (String?) -> Void) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(nil)
            return
        }
        let cloudinary = CLDCloudinary(configuration: CLDConfiguration(cloudName: "dkea6b2lm", apiKey: "915397132791353", apiSecret: "IAE2SY2hl3UnmMMj28SdOkY8Ces"))
        
        cloudinary.createUploader().upload(data: imageData, uploadPreset: "ml_default", progress: { (progress) in
            print("Upload progress: \(progress.fractionCompleted)")
        }, completionHandler: { (result, error) in
            if let error = error {
                print("Error uploading image: \(error.localizedDescription)")
                completion(nil)
                return
            }
            
            guard let result = result else {
                print("Upload result is nil")
                completion(nil)
                return
            }
            
            print("Upload result: \(result)")
            
            guard let url = result.secureUrl as String? else {
                print("Secure URL is nil")
                completion(nil)
                return
            }
            
            print("Image URL: \(url)")
            
            completion(url)
        })
        
    }
}
