//
//  ViewController.swift
//  RomoSwift
//
//  Created by Ken Tominaga on 11/8/14.
//  Copyright (c) 2014 Ken Tominaga. All rights reserved.
//

import UIKit
import Moscapsule

class ViewController: UIViewController, RMCoreDelegate{

    var romo: RMCharacter?
    var robot: RMCoreRobotRomo3?
    
    // Romo表情
    let numberOfExpressions: UInt32 = 32
    let numberOfEmotions: UInt32 = 10
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        // 設定ファイル読み込み
        let path = NSBundle.mainBundle().pathForResource("config", ofType: "json")
        let fileHandle = NSFileHandle(forReadingAtPath: path!)
        let data = fileHandle?.readDataToEndOfFile()
        
        let jsonString:String = NSString(data: data!, encoding: NSUTF8StringEncoding) as! String
        let json = JSON(string:jsonString)
        
        // Romo
        romo = RMCharacter.Romo()
        romo?.expression = RMCharacterExpressionCurious
        romo?.emotion = RMCharacterEmotionScared
        romo?.lookAtPoint(RMPoint3D(x: -1.0, y: -1.0, z: 0.5), animated: true)
        
        RMCore.setDelegate(self)
        
        // Iを通常通りに使うことができる
        let con = RMCoreControllerPID()
        con.I = 5
        print(con.I)
        
        let myBoundSize: CGSize = UIScreen.mainScreen().bounds.size
        let myBoundSizeStr: NSString = "Bounds width: \(myBoundSize.width) height: \(myBoundSize.height)"
        print(myBoundSizeStr)
        
        let myAppFrameSize: CGSize = UIScreen.mainScreen().applicationFrame.size
        let myAppFrameSizeStr: NSString = "applicationFrame width: \(myAppFrameSize.width) NativeBoundheight: \(myAppFrameSize.height)"
        print (myAppFrameSizeStr)
        
        // MQTT
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0), { () -> Void in
            let now = NSDate() // 現在日時の取得
            let dateFormatter = NSDateFormatter()
            dateFormatter.locale = NSLocale(localeIdentifier: "en_US") // ロケールの設定
            dateFormatter.dateFormat = "yyyyMMddHHmmss" // 日付フォーマットの設定
        
            let client = "client" + dateFormatter.stringFromDate(now)
        
            let mqttConfig = MQTTConfig(clientId: client, host: json["mqtt"]["host"].asString!, port: 1883, keepAlive: 60)
            mqttConfig.mqttAuthOpts = MQTTAuthOpts(username: json["mqtt"]["uuid"].asString!, password: json["mqtt"]["password"].asString!)
        
//            mqttConfig.onPublishCallback = { messageId in
//                NSLog("published (mid=\(messageId))")
//            }
            mqttConfig.onSubscribeCallback = { (messageId, grantedQos) in
                NSLog("subscribed (mid=\(messageId),grantedQos=\(grantedQos))")
            }
            mqttConfig.onMessageCallback = { mqttMessage in
                NSLog("MQTT Message received: payload=\(mqttMessage.payloadString)")
            
                let msg  : String   = mqttMessage.payloadString!
                let jsonMqtt = JSON(string:msg)
//                if let tweet = jsonMqtt["data"]["payload"]["tweet"].asString {
                  if let tweet = jsonMqtt["data"]["payload"].asString {
                    let base_url = json["mextractr"]["url"].asString!
                    let apikey = json["mextractr"]["apikey"].asString!
                    let out = json["mextractr"]["out"].asString!
                    let text = tweet.stringByAddingPercentEncodingWithAllowedCharacters(NSCharacterSet.URLQueryAllowedCharacterSet())
                    let urlString = base_url + "?apikey=" + apikey + "&out=" + out + "&text=" + text!
                    let url = NSURL(string: urlString)!
                    let request = NSURLRequest(URL: url)
                    let session = NSURLSession.sharedSession()
                    session.dataTaskWithRequest(request) { (data, response, error) in
                        let jsonString: String = NSString(data: data!, encoding: NSASCIIStringEncoding)! as String
                        let json = JSON(string:jsonString)

                        var likedislikeString:String?
                        var joysadString:String?
                        var angerfearString:String?
                        var expression:UInt32?
                        var emotion:UInt32?
                        if let likedislike = json["likedislike"].asInt {
                            if likedislike >= 1{
                                expression = 6  // RMCharacterExpressionExcited
                                emotion = 10    // RMCharacterEmotionDelighted
                                
                                self.robot?.turnByAngle(-30.0, withRadius: 0.0, completion: nil)
                                sleep(1)
                                self.robot?.turnByAngle(30.0, withRadius: 0.0, completion: nil)
                                sleep(1)
                                self.robot?.stopDriving()
                            }
                            else if likedislike <= -1 {
                                expression = 27 // RMCharacterExpressionBewildered
                                emotion = 9     // RMCharacterEmotionBewildered
                        
                                self.robot?.driveForwardWithSpeed(0.1)
                                sleep(1)
                                self.robot?.driveBackwardWithSpeed(0.1)
                                sleep(1)
                                self.robot?.stopDriving()
                            }
                            print(likedislike)
                            likedislikeString = String(likedislike)
                        }
                        if let joysad = json["joysad"].asInt {
                            if joysad >= 1 {
                                expression = 8  // RMCharacterExpressionHappy
                                emotion = 3     // RMCharacterEmotionHappy
                            }
                            else if joysad <= -1 {
                                expression = 14 // RMCharacterExpressionSad
                                emotion = 4     // RMCharacterEmotionSad
                            }
                            print(joysad)
                            joysadString = String(joysad)
                        }
                        if let angerfear = json["angerfear"].asInt {
                            if angerfear >= 1{
                                expression = 1  // RMCharacterExpressionAngry
                                emotion = 8     // RMCharacterEmotionIndifferent
                                
                                self.robot?.tiltToAngle(130.0, completion: nil)
                                sleep(2)
                                self.robot?.tiltToAngle(70.0, completion: nil)
                                sleep(2)
                                self.robot?.tiltToAngle(130.0, completion: nil)
                                
                            }
                            else if angerfear <= -1{
                                expression = 15 // RMCharacterExpressionScared
                                emotion = 5     // RMCharacterEmotionScared
                                
                                self.robot?.LEDs.blinkWithPeriod(1.0, dutyCycle: 3.0)
                                sleep(3)
                                self.robot?.LEDs.turnOff()
                            }
                            print(angerfear)
                            angerfearString = String(angerfear)
                        }
                        
                        if expression != nil && emotion != nil {
                            self.romo?.setExpression(RMCharacterExpression(expression!), withEmotion: RMCharacterEmotion(emotion!))
                        }
                        else{
                            let randomExpression = RMCharacterExpression(arc4random_uniform(self.numberOfExpressions) + 1)
                            let randomEmotion = RMCharacterEmotion(arc4random_uniform(self.numberOfEmotions) + 1)
                            self.romo?.setExpression(randomExpression, withEmotion: randomEmotion)
                        }

                        dispatch_async(dispatch_get_main_queue(), {
                            for view in self.view.subviews {
                                if (view.isKindOfClass(UILabel)) {
                                    view.removeFromSuperview()
                                }
                            }
                    
                            let label = UILabel(frame: CGRectMake(0, 450, 320, 100))
                            label.numberOfLines = 4
                            label.textAlignment = NSTextAlignment.Center
                            label.text = tweet + "\n" + "LikeDislike : " + likedislikeString! + "\n" + "JoySad : " + joysadString! + "\n" + "AngerFear : " + angerfearString!
                    
                            self.view.addSubview(label)
                        })
                    }.resume()
                }
            }
        
            let mqttClient = MQTT.newConnection(mqttConfig)
            mqttClient.subscribe(json["mqtt"]["uuid"].asString!, qos: 2)
            /*
            sleep(2)
        //        mqttClient.publishString(payload, topic: "message", qos: 2, retain: false)
        //    sleep(2)
            */
        
            while true {
            }
        
            mqttClient.disconnect()            
        })
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        romo?.addToSuperview(self.view)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        romo?.removeFromSuperview()
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touchLocation = touches.first!.locationInView(self.view)
        lookAtPoint(touchLocation)
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        let touchLocation = touches.first!.locationInView(self.view)
        lookAtPoint(touchLocation)
    }
    
    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        romo?.lookAtDefault()

        let randomExpression = RMCharacterExpression(arc4random_uniform(numberOfExpressions) + 1)
        let randomEmotion = RMCharacterEmotion(arc4random_uniform(numberOfEmotions) + 1)

        romo?.setExpression(randomExpression, withEmotion: randomEmotion)
        
        for view in self.view.subviews {
            if (view.isKindOfClass(UILabel)) {
                view.removeFromSuperview()
            }
        }
        let label = UILabel(frame: CGRectMake(0, 450, 320, 100))
        label.numberOfLines = 4
        label.textAlignment = NSTextAlignment.Center
        label.text = self.randomWord(8)
        
        self.view.addSubview(label)
    }
    
    override func touchesCancelled(touches: Set<UITouch>!, withEvent event: UIEvent!) {
        romo?.lookAtDefault()
    }
    
    func lookAtPoint(touchLocation: CGPoint) {
        // Maxiumum distance from the center of the screen = half the width
        let w_2 = self.view.frame.size.width / 2
        
        // Maximum distance from the middle of the screen = half the height
        let h_2 = self.view.frame.size.height / 2
        
        // Ratio of horizontal location from center
        let x = (touchLocation.x - w_2) / w_2
        
        // Ratio of vertical location from middle
        let y = (touchLocation.y - h_2) / h_2
        
        // Since the touches are on Romo's face, they
        let z: CGFloat = 0.0
        
        // Romo expects a 3D point
        // x and y between -1 and 1, z between 0 and 1
        // z controls how far the eyes diverge
        // (z = 0 makes the eyes converge, z = 1 makes the eyes parallel)
        let lookPoint = RMPoint3D(x: x, y: y, z: z)
        
        // Tell Romo to look at the point
        // We don't animate because lookAtTouchLocation: runs at many Hertz
        romo?.lookAtPoint(lookPoint, animated: false)
    }
    
    // MARK: RMCoreDelegate
    
    func robotDidConnect(robot: RMCoreRobot!) {
        if robot.drivable && robot.headTiltable && robot.LEDEquipped {
            self.robot = robot as? RMCoreRobotRomo3
        }
    }
    
    func robotDidDisconnect(robot: RMCoreRobot!) {
        if robot == self.robot {
            self.robot = nil;
        }
    }
    
    func randomWord(divisor: UInt32) -> String {
        let wordNo = Int(1 + (arc4random() % divisor))
        
        switch wordNo {
        case 1:
            return "Hello, My name is Romo"
        case 2:
            return "once in a blue moon"
        case 3:
            return "What's up?"
        case 4:
            return "Try not to make waves"
        case 5:
            return "Never say never"
        case 6:
            return "Up to you"
        case 7:
            return "The sky is the limit"
        case 8:
            return "Don't think.　FEEL!"
        case 9:
            return "Not at all"
        default:
            return "I'll be right here"
        }
    }
}

