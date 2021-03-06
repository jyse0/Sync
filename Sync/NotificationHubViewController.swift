//
//  NotificationHubViewController.swift
//  Sync
//
//  Created by Gabriela Pulido on 10/19/20.
//  Copyright © 2020 Gabriela Pulido. All rights reserved.
//

import UIKit
import TwitterKit
import Firebase

struct Category {
    let name : String
    var items : [NSManagedObject]
}

struct Notification {
    var body = String()
    var time = String()
    var notificationType = String()
    var userID = String()
}

class SocialMediaTableViewCell: UITableViewCell {
    @IBOutlet weak var socialIcon: UIImageView!
    @IBOutlet weak var notificationBody: UILabel!
    @IBOutlet weak var notificationTime: UILabel!
}

class NotificationHubViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
    
    var twitterNotifications:[NSManagedObject] = []{
        didSet{
            notificationHubTable.reloadData()
        }
    }
    
    //DUMMY PLACEHOLDERS
    var instagramNotifications:[NSManagedObject] = []
    var linkedInNotifications:[NSManagedObject] = []
    var facebookNotifications :[NSManagedObject] = []
    
    var sections = [Category]()
    
    let transiton = MenuTransition()
    //0 - opening settings, 1 - settings open, 2 - social opt open, 3 - change pass open
    var topView = 0
    
    @IBOutlet weak var notificationHubTable: UITableView!{
        didSet {
            notificationHubTable.dataSource = self
            notificationHubTable.delegate = self
            notificationHubTable.dragInteractionEnabled = true
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        deleteAllRecords()
        getTwitterNotifications()
        sections = [Category(name: "Twitter", items: twitterNotifications), Category(name: "Instagram", items: instagramNotifications), Category(name: "LinkedIn", items: linkedInNotifications), Category(name: "Facebook", items: facebookNotifications)]
        notificationHubTable.backgroundColor = UIColor(named: "Background")
        self.view.backgroundColor = UIColor(named: "Background")
        
        definesPresentationContext = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if((TWTRTwitter.sharedInstance().sessionStore.session()?.userID) != nil){
            getTwitterNotifications()
        }else{
            deleteAllRecords()
            twitterNotifications = []
            notificationHubTable.reloadData()
        }
    }
    
    func deleteAllRecords() {
        let delegate = UIApplication.shared.delegate as! AppDelegate
        let context = delegate.persistentContainer.viewContext
        
        let deleteFetch = NSFetchRequest<NSFetchRequestResult>(entityName: "NotificationEntity")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: deleteFetch)
        
        do {
            try context.execute(deleteRequest)
            try context.save()
        } catch {
            print ("There was an error")
        }
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "tableCell") as! SocialMediaTableViewCell
        cell.backgroundColor = UIColor(named: "blueButton")
        switch sections[indexPath.section].name {
        case "Twitter":
            if(TWTRTwitter.sharedInstance().sessionStore.session() != nil && twitterNotifications.count != 0 ){
                let notification = self.twitterNotifications[twitterNotifications.count - 1]
                var body:String? = notification.value(forKey: "notificationContent") as! String
                switch notification.value(forKey: "notificationType") as? String{
                case "Retweet":
                    cell.notificationBody.text = "Your tweet \(body!) was retweeted."
                case "Mention":
                    cell.notificationBody.text = "You were mentioned in a tweet: \(body!)"
                default:
                    print("default")
                }
                cell.notificationTime.text = notification.value(forKey: "time") as? String
            }
            cell.socialIcon.image = UIImage(named: "twitter-64")
            
            
        case "Instagram":
            cell.socialIcon.image = UIImage(named: "instagram-64")
        case "LinkedIn":
            cell.socialIcon.image = UIImage(named: "linkedin-3-64")
        case "Facebook":
            cell.socialIcon.image = UIImage(named: "facebook-3-64")
        default:
            print("Error")
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath){
        tableView.deselectRow(at: indexPath, animated: true)
        switch sections[indexPath.section].name {
        case "Twitter":
            self.performSegue(withIdentifier: "TwitterChannelSegue", sender: self)
        case "Instagram":
            self.performSegue(withIdentifier: "MessengerChannelSegue", sender: self)
        case "LinkedIn":
            self.performSegue(withIdentifier: "LinkedInChannelSegue", sender: self)
        case "Facebook":
            self.performSegue(withIdentifier: "FacebookChannelSegue", sender: self)
        default:
            print("default")
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "TwitterChannelSegue",
           let nextVC = segue.destination as? TwitterChannelViewController {
            // the button to change the color has been pressed
            nextVC.fullNotifications = twitterNotifications
            
        }
    }
    
    func getTwitterNotifications(){
        let userID : String = (Auth.auth().currentUser?.uid)!
        if(TWTRTwitter.sharedInstance().sessionStore.session() != nil){
            twitterNotifications = []
            //Get recent retweets
            let client = TWTRAPIClient.withCurrentUser()
            let request = client.urlRequest(withMethod: "GET",
                                            urlString: "https://api.twitter.com/1.1/statuses/retweets_of_me.json",
                                            parameters: ["count": "20"],
                                            error: nil)
            client.sendTwitterRequest(request)
            { response, data, connectionError in
                let json = try? JSONSerialization.jsonObject(with: data!, options: [])
                if let JSONString = String(data: data!, encoding: String.Encoding.utf8) {
                }
                let jsonResult: NSArray! = try? JSONSerialization.jsonObject(with: data!, options:[]) as! NSArray
                
                if (jsonResult != nil) {
                    for retweet in jsonResult {
                        let dict = retweet as? NSDictionary
                        // process jsonResult
                        let newRetweet = Notification(body: dict!["text"]! as! String, time: dict!["created_at"] as! String, notificationType: "Retweet", userID: userID)
                        var found = false;
                        for stored in self.twitterNotifications{
                            if (stored.value(forKey: "notificationContent") as! String == newRetweet.body){
                                found = true;
                            }
                        }
                        if(!found){
                            self.storeNotification(notif: newRetweet)
                            self.notificationHubTable.reloadData()
                        }
                    }
                } else {
                    // couldn't load JSON, look at error
                }
            }
            //Get recent mentions
            let mentionRequest = client.urlRequest(withMethod: "GET",
                                                   urlString: "https://api.twitter.com/1.1/statuses/mentions_timeline.json",
                                                   parameters: ["count": "20"],
                                                   error: nil)
            client.sendTwitterRequest(mentionRequest){ response, data, connectionError in
                let json = try? JSONSerialization.jsonObject(with: data!, options: [])
                let jsonResult: NSArray! = try? JSONSerialization.jsonObject(with: data!, options:[]) as! NSArray
                
                if (jsonResult != nil) {
                    for mention in jsonResult {
                        let dict = mention as? NSDictionary
                        let newMention = Notification(body: dict!["text"]! as! String, time: dict!["created_at"] as! String, notificationType: "Mention", userID: userID)
                        var found = false;
                        for stored in self.twitterNotifications{
                            if (stored.value(forKey: "notificationContent") as! String == newMention.body){
                                found = true;
                            }
                        }
                        if(!found){
                            self.storeNotification(notif: newMention)
                            self.notificationHubTable.reloadData()
                        }
                    }
                }
            }
            //Get recent DM's
            //            let dmRequest = client.urlRequest(withMethod: "GET",
            //                                                   urlString: "https://api.twitter.com/1.1/direct_messages/events/list.json",
            //                                                   parameters: ["count": "20"],
            //                                                   error: nil)
            //            client.sendTwitterRequest(dmRequest){ response, data, connectionError in
            //                let json = try? JSONSerialization.jsonObject(with: data!, options: [])
            //                let jsonResult: NSArray! = try? JSONSerialization.jsonObject(with: data!, options:[]) as! NSArray
            //
            //                if (jsonResult != nil) {
            //                    for dm in jsonResult {
            //                        let dict = dm as? NSDictionary
            //                        // process jsonResult
            //                        print("dm: \(dict!["text"]!)")
            //                        let newDM = Notification(body: dict!["text"]! as! String, time: "", notificationType: "DM")
            //                        self.twitterNotifications.append(newDM)
            //                        self.notificationHubTable.reloadData()
            //                    }
            //                }
            //            }
        }
        self.notificationHubTable.reloadData()
    }
    
    func storeNotification(notif: Notification){
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let notificationEntity = NSEntityDescription.insertNewObject(forEntityName: "NotificationEntity", into: context)
        
        //set the attribute values
        notificationEntity.setValue(notif.body, forKey: "notificationContent")
        notificationEntity.setValue(notif.notificationType, forKey: "notificationType")
        notificationEntity.setValue(notif.time, forKey: "time")
        notificationEntity.setValue(notif.userID, forKey: "user")
        
        //commit the changes
        do{
            try context.save()
            twitterNotifications = retrieveNotifications().filter{ $0.value(forKey: "user") as? String == ((Auth.auth().currentUser?.uid)!) }
        }catch{
            //if an error occurs
            let nserror = error as NSError
            NSLog("Unsolved error \(nserror), \(nserror.userInfo)")
            abort()
        }
    }
    
    func retrieveNotifications() -> [NSManagedObject]{
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        let context = appDelegate.persistentContainer.viewContext
        
        let request = NSFetchRequest<NSFetchRequestResult>(entityName: "NotificationEntity")
        
        var fetchedResults: [NSManagedObject]? = nil
        
        do{
            try fetchedResults = context.fetch(request) as? [NSManagedObject]
        }catch{
            //if an error occurs
            let nserror = error as NSError
            NSLog("Unsolved error \(nserror), \(nserror.userInfo)")
            abort()
        }
        return (fetchedResults)!
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return self.sections.count
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return self.sections[section].name
    }
    
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        //view.tintColor = UIColor(hue: 0.6167, saturation: 0.17, brightness: 0.44, alpha: 1.0)
        let header = view as! UITableViewHeaderFooterView
        //header.textLabel?.textColor = UIColor(hue: 0.125, saturation: 0.11, brightness: 0.98, alpha: 1.0)
    }
    
    @objc func handleTap(_ sender: UITapGestureRecognizer? = nil) {
        if((TWTRTwitter.sharedInstance().sessionStore.session()?.userID) != nil){
            getTwitterNotifications()
        }else{
            twitterNotifications = []
            deleteAllRecords()
            notificationHubTable.reloadData()
            
        }
        topView = 0
        self.title = "Channels"
        dismiss(animated: true, completion: nil)
    }
    
    //0 - opening settings, 1 - settings open, 2 - social opt open, 3 - change pass open
    @IBAction func hamTapped(_ sender: Any) {
        //opening settings
        notificationHubTable.reloadData()
        if topView == 0 {
            guard let settingsViewController = storyboard?.instantiateViewController(withIdentifier: "SettingsViewController") as? SettingsViewController else { return }
            
            let tap = UITapGestureRecognizer(target: self, action:    #selector(self.handleTap(_:)))
            transiton.dimmingView.addGestureRecognizer(tap)
            
            settingsViewController.didTapMenuType = { menuType in
                self.transitionToNew(menuType)
            }
            topView = 1
            self.title = "Settings"
            settingsViewController.modalPresentationStyle = .overCurrentContext
            settingsViewController.transitioningDelegate = self
            present(settingsViewController, animated: true)
        } else if topView > 0 { //then need to close
            handleTap()
        } else {
            print("Error hamTapped")
        }
    }
    
    func transitionToNew(_ menuType: MenuType) {
        switch menuType {
        case .addSocial:
            topView = 2
            guard let socialVC = storyboard?.instantiateViewController(withIdentifier: "optSocialVC") as? OptInViewController else { return }
            socialVC.modalPresentationStyle = .overCurrentContext
            socialVC.transitioningDelegate = self
            self.title = "Media Sign-In"
            present(socialVC, animated: true)
        case .passReset:
            topView = 3
            guard let passVC = storyboard?.instantiateViewController(withIdentifier: "changePassVC") as? ResetPasswordLoggedInViewController else { return }
            passVC.modalPresentationStyle = .overCurrentContext
            passVC.transitioningDelegate = self
            self.title = "Change Password"
            present(passVC, animated: true)
        default:
            break
        }
    }
}

extension NotificationHubViewController: UIViewControllerTransitioningDelegate {
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transiton.isPresenting = true
        return transiton
    }
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        transiton.isPresenting = false
        return transiton
    }
}
