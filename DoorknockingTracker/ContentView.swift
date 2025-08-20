import SwiftUI
import CoreLocation
import MapKit
import GoogleSignIn
import GoogleSignInSwift

// User model for authenticated user
struct AppUser: Codable {
    let id: String
    let email: String
    let name: String
    let profileImageURL: String?
    
    init(from gidUser: GIDGoogleUser) {
        self.id = gidUser.userID ?? ""
        self.email = gidUser.profile?.email ?? ""
        self.name = gidUser.profile?.name ?? ""
        self.profileImageURL = gidUser.profile?.imageURL(withDimension: 100)?.absoluteString
    }
}

class AuthenticationManager: ObservableObject {
    @Published var isSignedIn = false
    @Published var currentUser: AppUser?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let userDefaults = UserDefaults.standard
    private let userKey = "SavedUser"
    
    init() {
        loadSavedUser()
        checkCurrentSignInStatus()
    }
    
    // MARK: - Configuration
    func configureGoogleSignIn() {
        guard let path = Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["CLIENT_ID"] as? String else {
            print("❌ Could not find GoogleService-Info.plist or CLIENT_ID")
            return
        }
        
        let configuration = GIDConfiguration(clientID: clientId)
        GIDSignIn.sharedInstance.configuration = configuration
    }
    
    // MARK: - Sign In
    func signIn() {
        guard let presentingViewController = UIApplication.shared.windows.first?.rootViewController else {
            errorMessage = "Could not find presenting view controller"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        GIDSignIn.sharedInstance.signIn(withPresenting: presentingViewController) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Sign in failed: \(error.localizedDescription)"
                    return
                }
                
                guard let user = result?.user else {
                    self?.errorMessage = "Failed to get user information"
                    return
                }
                
                let appUser = AppUser(from: user)
                self?.currentUser = appUser
                self?.isSignedIn = true
                self?.saveUser(appUser)
                
                print("✅ Successfully signed in: \(appUser.name)")
            }
        }
    }
    
    // MARK: - Sign Out
    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        isSignedIn = false
        currentUser = nil
        clearSavedUser()
        print("✅ Successfully signed out")
    }
    
    // MARK: - Restore Previous Session
    func restorePreviousSignIn() {
        guard GIDSignIn.sharedInstance.hasPreviousSignIn() else {
            print("📝 No previous sign in found")
            return
        }
        
        isLoading = true
        
        GIDSignIn.sharedInstance.restorePreviousSignIn { [weak self] user, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    print("❌ Failed to restore sign in: \(error.localizedDescription)")
                    self?.clearSavedUser()
                    return
                }
                
                guard let user = user else {
                    print("❌ No user found during restore")
                    self?.clearSavedUser()
                    return
                }
                
                let appUser = AppUser(from: user)
                self?.currentUser = appUser
                self?.isSignedIn = true
                self?.saveUser(appUser)
                
                print("✅ Successfully restored sign in: \(appUser.name)")
            }
        }
    }
    
    // MARK: - Private Methods
    private func checkCurrentSignInStatus() {
        if GIDSignIn.sharedInstance.hasPreviousSignIn() {
            restorePreviousSignIn()
        }
    }
    
    private func saveUser(_ user: AppUser) {
        do {
            let encoded = try JSONEncoder().encode(user)
            userDefaults.set(encoded, forKey: userKey)
        } catch {
            print("❌ Failed to save user: \(error)")
        }
    }
    
    private func loadSavedUser() {
        guard let data = userDefaults.data(forKey: userKey) else { return }
        
        do {
            currentUser = try JSONDecoder().decode(AppUser.self, from: data)
        } catch {
            print("❌ Failed to load saved user: \(error)")
            clearSavedUser()
        }
    }
    
    private func clearSavedUser() {
        userDefaults.removeObject(forKey: userKey)
        currentUser = nil
    }
}

// MARK: - Sign In View
struct SignInView: View {
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            // App Logo/Icon Area
            VStack(spacing: 20) {
                Image(systemName: "house.and.flag.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                Text("Doorknocking Tracker")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Track your doorknocking activities with precision")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            Spacer()
            
            // Sign In Section
            VStack(spacing: 20) {
                Text("Sign in to get started")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if authManager.isLoading {
                    ProgressView("Signing in...")
                        .frame(height: 50)
                } else {
                    // Google Sign In Button
                    Button(action: {
                        authManager.signIn()
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.title2)
                            
                            Text("Sign in with Google")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [.blue, .blue.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                        .shadow(color: .blue.opacity(0.3), radius: 5, x: 0, y: 2)
                    }
                    .padding(.horizontal, 40)
                }
                
                // Error Message
                if let errorMessage = authManager.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            
            Spacer()
            
            // Privacy Note
            Text("Your data is stored securely and never shared without permission")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [Color.blue.opacity(0.05), Color.white]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

// MARK: - User Profile View
struct UserProfileView: View {
    let user: AppUser
    let onSignOut: () -> Void
    @State private var showingSignOutAlert = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Profile Header
            VStack(spacing: 12) {
                // Profile Image
                AsyncImage(url: URL(string: user.profileImageURL ?? "")) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.gray)
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.blue, lineWidth: 3)
                )
                
                // User Info
                VStack(spacing: 4) {
                    Text(user.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(user.email)
                        .font(.body)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
                .padding(.vertical)
            
            // Sign Out Button
            Button(action: {
                showingSignOutAlert = true
            }) {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .foregroundColor(.red)
                    Text("Sign Out")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    Spacer()
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(10)
            }
            
            Spacer()
        }
        .padding()
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                onSignOut()
            }
        } message: {
            Text("Are you sure you want to sign out?")
        }
    }
}

// MARK: - Updated RootAppView
struct RootAppView: View {
    @StateObject private var authManager = AuthenticationManager()
    
    var body: some View {
        Group {
            if authManager.isSignedIn && authManager.currentUser != nil {
                // Pass authManager to ContentView
                ContentViewWithSignOut(authManager: authManager)
            } else {
                SignInView(authManager: authManager)
            }
        }
        .onAppear {
            authManager.configureGoogleSignIn()
        }
    }
}

// MARK: - ContentView Wrapper with Sign Out Button
struct ContentViewWithSignOut: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showingSignOutAlert = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Your main content
            ContentView()
            
            // Sign out button at bottom
            VStack(spacing: 0) {
                Divider()
                
                Button(action: {
                    showingSignOutAlert = true
                }) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign Out")
                        Spacer()
                        if let user = authManager.currentUser {
                            Text(user.name)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.gray.opacity(0.05))
                }
            }
        }
        .alert("Sign Out", isPresented: $showingSignOutAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Sign Out", role: .destructive) {
                authManager.signOut()
            }
        } message: {
            Text("Are you sure you want to sign out? Your data will remain on this device.")
        }
    }
}


// Testing this change
// MARK: - Activity Data Models
struct ActivityRecord: Identifiable, Codable {
    let recordID: UUID
    let timestamp: Date
    let currentLocation: String
    let activityButtonPressed: String
    
    // Computed property for table display
    var id: UUID { recordID }
    
    // Formatted timestamp for display
    var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: timestamp)
    }
    
    // CSV-formatted timestamp
    var csvTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    // Initializer
    init(currentLocation: String, activityButtonPressed: String) {
        self.recordID = UUID()
        self.timestamp = Date()
        self.currentLocation = currentLocation
        self.activityButtonPressed = activityButtonPressed
    }
}

// MARK: - Activity Manager
class ActivityManager: ObservableObject {
    @Published var activityLog: [ActivityRecord] = []
    
    private let userDefaults = UserDefaults.standard
    private let storageKey = "DoorknockingActivityLog"
    
    init() {
        loadActivityLog()
    }
    
    // MARK: - Add New Activity
    func logActivity(currentLocation: String, activityButtonPressed: String) {
        let newRecord = ActivityRecord(
            currentLocation: currentLocation,
            activityButtonPressed: activityButtonPressed
        )
        
        // Add to beginning of array (newest first)
        activityLog.insert(newRecord, at: 0)
        
        // Save to persistent storage
        saveActivityLog()
        
        print("✅ Activity logged: \(activityButtonPressed) at \(currentLocation)")
    }
    
    // MARK: - Data Persistence
    private func saveActivityLog() {
        do {
            let encoded = try JSONEncoder().encode(activityLog)
            userDefaults.set(encoded, forKey: storageKey)
            print("💾 Activity log saved with \(activityLog.count) records")
        } catch {
            print("❌ Failed to save activity log: \(error)")
        }
    }
    
    private func loadActivityLog() {
        guard let data = userDefaults.data(forKey: storageKey) else {
            print("📝 No existing activity log found")
            return
        }
        
        do {
            activityLog = try JSONDecoder().decode([ActivityRecord].self, from: data)
            print("📂 Loaded \(activityLog.count) activity records")
        } catch {
            print("❌ Failed to load activity log: \(error)")
            activityLog = []
        }
    }
    
    // MARK: - Clear All Data
    func clearAllActivities() {
        activityLog.removeAll()
        saveActivityLog()
        print("🗑️ All activities cleared")
    }
    
    // MARK: - CSV Export
    func generateCSV() -> String {
        var csvContent = "Record ID,Timestamp,Current Location,Activity Button Pressed\n"
        
        for record in activityLog.reversed() { // Export in chronological order
            let escapedLocation = escapeCSVField(record.currentLocation)
            let escapedActivity = escapeCSVField(record.activityButtonPressed)
            
            csvContent += "\(record.recordID.uuidString),\(record.csvTimestamp),\(escapedLocation),\(escapedActivity)\n"
        }
        
        return csvContent
    }
    
    private func escapeCSVField(_ field: String) -> String {
        if field.contains(",") || field.contains("\"") || field.contains("\n") {
            return "\"\(field.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return field
    }
    
    // MARK: - Statistics
    var todayActivities: [ActivityRecord] {
        let calendar = Calendar.current
        let today = Date()
        
        return activityLog.filter { record in
            calendar.isDate(record.timestamp, inSameDayAs: today)
        }
    }
    
    var activityCounts: (total: Int, flyers: Int, conversations: Int, doNotContact: Int) {
        let today = todayActivities
        let flyers = today.filter { $0.activityButtonPressed == "Flyer Dropped Off" }.count
        let conversations = today.filter { $0.activityButtonPressed == "Conversation Had" }.count
        let doNotContact = today.filter { $0.activityButtonPressed == "Don't Contact Me Again" }.count
        
        return (today.count, flyers, conversations, doNotContact)
    }
}

// MARK: - Data Models
struct Property: Identifiable, Codable {
    let id = UUID()
    let address: String
    let ownerName: String
    let bedrooms: Int
    let bathrooms: Double
    let yearBuilt: Int
    let sqFeet: Int
    let lotSize: String
    let yearsOwned: Int
    let salesPrice: Int
    let soldDate: String
    
    // For CSV parsing
    init(address: String, ownerName: String, bedrooms: String, bathrooms: String,
         yearBuilt: String, sqFeet: String, lotSize: String, yearsOwned: String,
         salesPrice: String, soldDate: String) {
        self.address = address.trimmingCharacters(in: .whitespacesAndNewlines)
        self.ownerName = ownerName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.bedrooms = Int(bedrooms.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        self.bathrooms = Double(bathrooms.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0.0
        self.yearBuilt = Int(yearBuilt.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        self.sqFeet = Int(sqFeet.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        self.lotSize = lotSize.trimmingCharacters(in: .whitespacesAndNewlines)
        self.yearsOwned = Int(yearsOwned.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        self.salesPrice = Int(salesPrice.trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        self.soldDate = soldDate.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // Computed properties for display formatting
    var formattedSalesPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: salesPrice)) ?? "$0"
    }
    
    var formattedSqFeet: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return "\(formatter.string(from: NSNumber(value: sqFeet)) ?? "0") sq ft"
    }
    
    var bedroomBathroomText: String {
        let bathroomString = bathrooms.truncatingRemainder(dividingBy: 1) == 0 ?
            String(Int(bathrooms)) : String(bathrooms)
        return "\(bedrooms) bed, \(bathroomString) bath"
    }
}

// comment added
// one more
// MARK: - Location Manager
class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published var currentLocation: CLLocation?
    @Published var currentAddress: String = ""
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.distanceFilter = 5 // Update every 10 meters
    }
    
    func requestLocation() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            errorMessage = "Location access denied. Please enable in Settings."
        case .authorizedWhenInUse, .authorizedAlways:
            startLocationUpdates()
        @unknown default:
            break
        }
    }
    
    private func startLocationUpdates() {
        isLoading = true
        errorMessage = nil
        locationManager.startUpdatingLocation()
    }
    
    func stopLocationUpdates() {
        locationManager.stopUpdatingLocation()
        isLoading = false
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            startLocationUpdates()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        currentLocation = location
        
        // Reverse geocode to get street address
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            DispatchQueue.main.async {
                self?.isLoading = false
                
                if let error = error {
                    self?.errorMessage = "Failed to get address: \(error.localizedDescription)"
                    return
                }
                
                if let placemark = placemarks?.first {
                    let address = self?.formatAddress(from: placemark) ?? "Unknown Address"
                    self?.currentAddress = address
                }
            }
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.isLoading = false
            self.errorMessage = "Location error: \(error.localizedDescription)"
        }
    }
    
    private func formatAddress(from placemark: CLPlacemark) -> String {
        var components: [String] = []
        
        if let streetNumber = placemark.subThoroughfare {
            components.append(streetNumber)
        }
        if let streetName = placemark.thoroughfare {
            components.append(streetName)
        }
        
        return components.joined(separator: " ")
    }
}

// MARK: - Property Data Manager
class PropertyDataManager: ObservableObject {
    @Published var properties: [Property] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    init() {
        loadPropertiesFromCSV()
    }
    
    func loadPropertiesFromCSV() {
        // In a real app, you'd load from your CSV file in the bundle
        // For now, here's how you'd structure it:
        
        guard let path = Bundle.main.path(forResource: "properties", ofType: "csv"),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            // If no CSV file, use sample data for demonstration
            loadSampleData()
            return
        }
        
        parseCSV(content: content)
    }
    
    private func parseCSV(content: String) {
        isLoading = true
        errorMessage = nil
        
        let lines = content.components(separatedBy: .newlines)
        var tempProperties: [Property] = []
        
        // Skip header row if it exists
        let dataLines = lines.dropFirst()
        
        for line in dataLines {
            let components = line.components(separatedBy: ",")
            if components.count >= 10 {
                // Remove quotes from each component
                let cleanComponents = components.map { component in
                    component.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                }
                
                let property = Property(
                    address: cleanComponents[0],
                    ownerName: cleanComponents[1],
                    bedrooms: cleanComponents[2],
                    bathrooms: cleanComponents[3],
                    yearBuilt: cleanComponents[4],
                    sqFeet: cleanComponents[5],
                    lotSize: cleanComponents[6],
                    yearsOwned: cleanComponents[7],
                    salesPrice: cleanComponents[8],
                    soldDate: cleanComponents[9]
                )
                
                if !property.address.isEmpty && !property.ownerName.isEmpty {
                    tempProperties.append(property)
                }
            }
        }
        
        DispatchQueue.main.async {
            self.properties = tempProperties
            self.isLoading = false
        }
    }
    
    private func loadSampleData() {
        // Sample data for demonstration
        properties = [
            Property(address: "123 Main St", ownerName: "John Smith", bedrooms: "4",
                    bathrooms: "2.5", yearBuilt: "1995", sqFeet: "2400", lotSize: "0.25 acres",
                    yearsOwned: "8", salesPrice: "450000", soldDate: "2016-03-15"),
            Property(address: "456 Oak Ave", ownerName: "Jane Doe", bedrooms: "3",
                    bathrooms: "2", yearBuilt: "2003", sqFeet: "1850", lotSize: "0.18 acres",
                    yearsOwned: "5", salesPrice: "380000", soldDate: "2019-07-22"),
            Property(address: "789 Pine Rd", ownerName: "Bob Johnson", bedrooms: "5",
                    bathrooms: "3", yearBuilt: "1987", sqFeet: "2800", lotSize: "0.35 acres",
                    yearsOwned: "12", salesPrice: "520000", soldDate: "2012-11-08"),
            Property(address: "321 Elm St", ownerName: "Alice Brown", bedrooms: "2",
                    bathrooms: "1.5", yearBuilt: "2010", sqFeet: "1200", lotSize: "0.12 acres",
                    yearsOwned: "3", salesPrice: "295000", soldDate: "2021-09-30"),
            Property(address: "654 Maple Dr", ownerName: "Charlie Wilson", bedrooms: "4",
                    bathrooms: "3.5", yearBuilt: "1999", sqFeet: "2650", lotSize: "0.28 acres",
                    yearsOwned: "7", salesPrice: "485000", soldDate: "2017-05-12")
        ]
    }
    
    func findProperty(by address: String) -> Property? {
        let searchAddress = address.lowercased()
        
        return properties.first { property in
            let propertyAddress = property.address.lowercased()
            
            // Exact match first
            if propertyAddress == searchAddress {
                return true
            }
            
            // Partial match - check if current address contains property address keywords
            let addressWords = searchAddress.components(separatedBy: .whitespaces)
            let propertyWords = propertyAddress.components(separatedBy: .whitespaces)
            
            // Check if the property address words are contained in the current address
            let matchingWords = propertyWords.filter { propertyWord in
                addressWords.contains { addressWord in
                    addressWord.contains(propertyWord) || propertyWord.contains(addressWord)
                }
            }
            
            // Consider it a match if most words match
            return matchingWords.count >= max(1, propertyWords.count - 1)
        }
    }
}

// MARK: - Daily Stats View
struct DailyStatsView: View {
    let stats: (total: Int, flyers: Int, conversations: Int, doNotContact: Int)
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Activity")
                .font(.headline)
            
            HStack(spacing: 10) {
                StatCard(title: "Total", value: "\(stats.total)", color: .blue)
                StatCard(title: "Flyers", value: "\(stats.flyers)", color: .blue)
                StatCard(title: "Talks", value: "\(stats.conversations)", color: .green)
                StatCard(title: "DNC", value: "\(stats.doNotContact)", color: .red)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white)
        .cornerRadius(6)
        .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
    }
}

// MARK: - Activity Table View
struct ActivityTableView: View {
    @ObservedObject var activityManager: ActivityManager
    @State private var showingClearAlert = false
    @State private var showingExportSheet = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            // Header with controls
            HStack {
                Text("Activity Log")
                    .font(.headline)
                
                Spacer()
                
                if !activityManager.activityLog.isEmpty {
                    HStack(spacing: 12) {
                        Button(action: {
                            showingExportSheet = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                        
                        Button(action: {
                            showingClearAlert = true
                        }) {
                            Text("Clear All")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                }
            }
            
            // Activity count
            if !activityManager.activityLog.isEmpty {
                Text("\(activityManager.activityLog.count) total activities")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Table content
            if activityManager.activityLog.isEmpty {
                // Empty state
                VStack(spacing: 12) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("No Activities Logged")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text("Press the activity buttons above to start tracking your doorknocking activities")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(10)
            } else {
                // Activity list
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(activityManager.activityLog) { record in
                            ActivityRowView(record: record)
                        }
                    }
                }
                .frame(maxHeight: 250)
                .background(Color.gray.opacity(0.02))
                .cornerRadius(8)
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            CSVExportView(activityManager: activityManager)
        }
        .alert("Clear All Activities", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear All", role: .destructive) {
                activityManager.clearAllActivities()
            }
        } message: {
            Text("Are you sure you want to delete all \(activityManager.activityLog.count) activity records? This action cannot be undone.")
        }
    }
}

// MARK: - Activity Row View
struct ActivityRowView: View {
    let record: ActivityRecord
    
    var activityColor: Color {
        switch record.activityButtonPressed {
        case "Flyer Dropped Off":
            return .blue
        case "Conversation Had":
            return .green
        case "Don't Contact Me Again":
            return .red
        default:
            return .gray
        }
    }
    
    var activityIcon: String {
        switch record.activityButtonPressed {
        case "Flyer Dropped Off":
            return "doc.fill"
        case "Conversation Had":
            return "bubble.left.and.bubble.right.fill"
        case "Don't Contact Me Again":
            return "hand.raised.fill"
        default:
            return "circle.fill"
        }
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Activity icon
            Image(systemName: activityIcon)
                .foregroundColor(activityColor)
                .font(.system(size: 16, weight: .medium))
                .frame(width: 24, height: 24)
            
            // Activity details
            VStack(alignment: .leading, spacing: 2) {
                Text(record.activityButtonPressed)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                
                Text(record.currentLocation)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Timestamp
            Text(record.formattedTimestamp)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .padding(12)
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

// MARK: - CSV Export View
struct CSVExportView: View {
    @ObservedObject var activityManager: ActivityManager
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Export icon and title
                VStack(spacing: 12) {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.blue)
                    
                    Text("Export Activity Log")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Export \(activityManager.activityLog.count) activities to CSV format")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                
                // CSV preview
                VStack(alignment: .leading, spacing: 10) {
                    Text("CSV Format:")
                        .font(.headline)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Record ID,Timestamp,Current Location,Activity Button Pressed")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                        
                        if let firstRecord = activityManager.activityLog.first {
                            Text("\(firstRecord.recordID.uuidString.prefix(8))...,\(firstRecord.csvTimestamp),\(firstRecord.currentLocation),\(firstRecord.activityButtonPressed)")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                        }
                    }
                    .padding(12)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                Spacer()
                
                // Export button
                Button(action: {
                    exportToCSV()
                }) {
                    HStack {
                        if isExporting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Text("Export to CSV")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .disabled(isExporting || activityManager.activityLog.isEmpty)
                .padding(.horizontal)
            }
            .navigationTitle("Export Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func exportToCSV() {
        isExporting = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let csvContent = activityManager.generateCSV()
            
            DispatchQueue.main.async {
                self.isExporting = false
                self.shareCSV(csvContent)
            }
        }
    }
    
    private func shareCSV(_ csvContent: String) {
        let filename = "doorknocking_log_\(currentDateString()).csv"
        
        // Use a simpler approach that works reliably
        saveToDocumentsWithFilesApp(csvContent: csvContent, filename: filename)
    }
    
    private func saveToDocumentsWithFilesApp(csvContent: String, filename: String) {
        // First dismiss the current sheet
        dismiss()
        
        // Wait a moment for the dismiss animation to complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                print("❌ Could not access documents directory")
                return
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(filename)
            
            do {
                try csvContent.write(to: fileURL, atomically: true, encoding: .utf8)
                print("✅ CSV file saved to: \(fileURL.path)")
                
                // Present activity controller with the saved file
                let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
                
                // Add a custom activity for "Save to Files"
                activityVC.excludedActivityTypes = [
                    .addToReadingList,
                    .assignToContact,
                    .postToFacebook,
                    .postToTwitter,
                    .postToWeibo,
                    .postToVimeo,
                    .postToTencentWeibo,
                    .postToFlickr
                ]
                
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let rootVC = window.rootViewController {
                    
                    // Configure for iPad
                    if let popover = activityVC.popoverPresentationController {
                        popover.sourceView = window
                        popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                        popover.permittedArrowDirections = []
                    }
                    
                    rootVC.present(activityVC, animated: true)
                }
                
                // Show a success message
                self.showExportSuccess(filename: filename)
                
            } catch {
                print("❌ Error writing CSV file: \(error)")
                self.showExportError()
            }
        }
    }
    
    private func showExportSuccess(filename: String) {
        // You can add a toast/alert here if desired
        print("✅ Export successful: \(filename)")
    }
    
    private func showExportError() {
        // You can add error handling UI here if desired
        print("❌ Export failed")
    }
    
    private func currentDateString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        return formatter.string(from: Date())
    }
}

// MARK: - Property Details View
struct PropertyDetailsView: View {
    let property: Property?
    let onBack: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            // Header with Back Button
            HStack {
                Button(action: onBack) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                    .foregroundColor(.blue)
                    .font(.system(size: 16, weight: .medium))
                }
                
                Spacer()
                
                Text("Property Details")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                // Invisible spacer to center the title
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .opacity(0)
            }
            .padding(.horizontal)
            
            // Property Information Content
            ScrollView {
                if let property = property {
                    VStack(spacing: 20) {
                        // Property Address Card
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Property Address")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Text(property.address)
                                .font(.title2)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Simple Property Details (without grid)
                        VStack(alignment: .leading, spacing: 12) {
                            PropertyInfoRow(label: "Owner", value: property.ownerName, valueColor: .blue)
                            PropertyInfoRow(label: "Bedrooms", value: "\(property.bedrooms)")
                            PropertyInfoRow(label: "Bathrooms", value: String(format: "%.1f", property.bathrooms))
                            PropertyInfoRow(label: "Year Built", value: "\(property.yearBuilt)")
                            PropertyInfoRow(label: "Square Feet", value: property.formattedSqFeet)
                            PropertyInfoRow(label: "Lot Size", value: property.lotSize)
                            PropertyInfoRow(label: "Years Owned", value: "\(property.yearsOwned) years")
                            PropertyInfoRow(label: "Sales Price", value: property.formattedSalesPrice)
                            PropertyInfoRow(label: "Sold Date", value: property.soldDate)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal)
                } else {
                    // No Property Found
                    VStack(spacing: 16) {
                        Image(systemName: "house.slash.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No Property Found")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        Text("We couldn't find property information for this address. The property might not be in our database.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 60)
                }
            }
        }
    }
}

// MARK: - Main ContentView
struct ContentView: View {
    @StateObject private var locationManager = LocationManager()
    @StateObject private var propertyManager = PropertyDataManager()
    @StateObject private var activityManager = ActivityManager()
    @State private var foundProperty: Property?
    @State private var showingPropertyDetails = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if showingPropertyDetails {
                    // Property Details View
                    PropertyDetailsView(
                        property: foundProperty,
                        onBack: {
                            showingPropertyDetails = false
                        }
                    )
                } else {
                    // Main Property Lookup Screen
                    ScrollView {
                        VStack(spacing: 20) {
                            // Header
                            Text("Doorknocking Tracker")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                            
                            // Daily Stats
                            DailyStatsView(stats: activityManager.activityCounts)
                            
                            // Location Section
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Current Location")
                                    .font(.headline)
                                
                                if locationManager.isLoading {
                                    HStack {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                        Text("Getting location...")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                } else if !locationManager.currentAddress.isEmpty {
                                    HStack {
                                        Text(locationManager.currentAddress)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                } else {
                                    HStack {
                                        Text("No location available")
                                            .foregroundColor(.secondary)
                                        Spacer()
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                                
                                // Location Button
                                Button(action: {
                                    locationManager.requestLocation()
                                }) {
                                    HStack {
                                        Image(systemName: "location.fill")
                                        Text("Get Current Location")
                                        Spacer()
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .disabled(locationManager.isLoading)
                                
                                // Search Property Button (Navigation Trigger)
                                Button(action: {
                                    searchProperty()
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showingPropertyDetails = true
                                    }
                                }) {
                                    HStack {
                                        Image(systemName: "magnifyingglass")
                                        Text("Search Property")
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                    }
                                    .foregroundColor(.white)
                                    .padding()
                                    .background(Color.green)
                                    .cornerRadius(10)
                                }
                                .disabled(locationManager.currentAddress.isEmpty)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // Activity Buttons Section
                            VStack(spacing: 15) {
                                Text("Activity Buttons")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                VStack(spacing: 12) {
                                    // Button 1: Flyer Dropped Off
                                    Button(action: {
                                        activityManager.logActivity(
                                            currentLocation: locationManager.currentAddress,
                                            activityButtonPressed: "Flyer Dropped Off"
                                        )
                                    }) {
                                        HStack {
                                            Image(systemName: "doc.fill")
                                            Text("Flyer Dropped Off")
                                            Spacer()
                                        }
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.blue)
                                        .cornerRadius(10)
                                    }
                                    .disabled(locationManager.currentAddress.isEmpty)
                                    
                                    // Button 2: Conversation Had
                                    Button(action: {
                                        activityManager.logActivity(
                                            currentLocation: locationManager.currentAddress,
                                            activityButtonPressed: "Conversation Had"
                                        )
                                    }) {
                                        HStack {
                                            Image(systemName: "bubble.left.and.bubble.right.fill")
                                            Text("Conversation Had")
                                            Spacer()
                                        }
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.green)
                                        .cornerRadius(10)
                                    }
                                    .disabled(locationManager.currentAddress.isEmpty)
                                    
                                    // Button 3: Don't Contact Me Again
                                    Button(action: {
                                        activityManager.logActivity(
                                            currentLocation: locationManager.currentAddress,
                                            activityButtonPressed: "Don't Contact Me Again"
                                        )
                                    }) {
                                        HStack {
                                            Image(systemName: "hand.raised.fill")
                                            Text("Don't Contact Me Again")
                                            Spacer()
                                        }
                                        .foregroundColor(.white)
                                        .padding()
                                        .background(Color.red)
                                        .cornerRadius(10)
                                    }
                                    .disabled(locationManager.currentAddress.isEmpty)
                                }
                            }
                            .padding(.vertical)
                            
                            // Activity Table
                            ActivityTableView(activityManager: activityManager)
                            
                            // Error Messages
                            if let errorMessage = locationManager.errorMessage {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .padding()
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            
                            Spacer()
                            
                            // Data Info
                            Text("Loaded \(propertyManager.properties.count) properties")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                }
            }
        }
        .onChange(of: locationManager.currentAddress) { oldValue, newValue in
            // Don't auto-search when address changes
        }
    }
    
    private func searchProperty() {
        foundProperty = propertyManager.findProperty(by: locationManager.currentAddress)
    }
}

// MARK: - Helper Views
struct PropertyInfoRow: View {
    let label: String
    let value: String
    var valueColor: Color = .primary
    
    var body: some View {
        HStack {
            Text("\(label):")
                .fontWeight(.semibold)
                .frame(width: 100, alignment: .leading)
            Text(value)
                .foregroundColor(valueColor)
                .fontWeight(valueColor == .primary ? .regular : .medium)
            Spacer()
        }
        .font(.system(size: 14))
    }
}

// MARK: - Preview
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
